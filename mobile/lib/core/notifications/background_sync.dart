/// Controllo periodico delle notifiche mentre l'app non è in esecuzione.
///
/// Il canale Realtime della PWA e quello dell'app funzionano solo con il
/// processo vivo: appena il sistema chiude l'app, l'utente smette di ricevere
/// qualsiasi avviso. Qui il sistema operativo risveglia un isolate separato a
/// intervalli regolari, che rilegge le notifiche non lette da Supabase e le
/// pubblica come banner.
///
/// Limiti reali, da conoscere:
/// - su Android l'intervallo minimo imposto da WorkManager è 15 minuti, e il
///   task non gira se l'utente forza la chiusura dell'app dalle impostazioni;
/// - su iOS il `BGAppRefreshTask` è opportunistico: il sistema decide quando
///   concederlo in base all'uso dell'app, quindi può passare molto più tempo.
///
/// Per un avviso immediato ad app chiusa serve un canale push vero (FCM su
/// Android, APNs su iOS), che richiede credenziali degli account Google e Apple
/// del proprietario: vedi la sezione Notifiche del README.
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import 'notification_service.dart';

/// Nome del task periodico registrato su WorkManager.
const _taskName = 'kickly-notification-poll';

/// Identificativo univoco: ri-registrare con lo stesso nome aggiorna il task
/// esistente invece di crearne un secondo.
const _taskUniqueName = 'kickly-notification-poll-unique';

/// Chiave della data dell'ultima notifica già mostrata.
///
/// Evita che a ogni risveglio vengano ripubblicate le stesse notifiche.
const _cursorKey = 'kickly.notifications.lastSeenAt';

/// Numero massimo di banner per risveglio: se uno resta offline a lungo è
/// meglio un riassunto breve che venti notifiche in fila.
const _maxPerRun = 5;

/// Intervallo richiesto al sistema. Android non scende comunque sotto i 15
/// minuti, iOS lo tratta come un suggerimento.
const _interval = Duration(minutes: 15);

/// Punto di ingresso invocato dal sistema nell'isolate di background.
///
/// Deve essere una funzione top-level annotata `vm:entry-point`, altrimenti
/// viene rimossa dal tree shaking in release e il task fallisce in silenzio.
@pragma('vm:entry-point')
void notificationPollDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      return await _pollNotifications();
    } catch (error) {
      debugPrint('Controllo notifiche in background fallito: $error');
      // false chiede al sistema di riprovare con backoff.
      return false;
    }
  });
}

/// Registra il task periodico. Va chiamato dopo il login.
Future<void> startNotificationPolling() async {
  final config = AppConfig.fromEnvironment();
  if (!config.hasSupabase) return; // modalità demo: niente da sincronizzare
  await Workmanager().initialize(notificationPollDispatcher);
  await Workmanager().registerPeriodicTask(
    _taskUniqueName,
    _taskName,
    frequency: _interval,
    // Senza rete la query fallirebbe: meglio che il sistema rimandi.
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Ferma il task e azzera il cursore, al logout.
Future<void> stopNotificationPolling() async {
  await Workmanager().cancelByUniqueName(_taskUniqueName);
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cursorKey);
}

/// Segna come già viste tutte le notifiche fino a [when].
///
/// Chiamato dall'app in primo piano quando mostra una notifica: senza questo,
/// al risveglio successivo il task in background la ripubblicherebbe.
Future<void> markNotificationsSeen(DateTime when) async {
  final prefs = await SharedPreferences.getInstance();
  final current = DateTime.tryParse(prefs.getString(_cursorKey) ?? '');
  if (current != null && !when.isAfter(current)) return;
  await prefs.setString(_cursorKey, when.toUtc().toIso8601String());
}

/// Corpo del controllo: legge le notifiche nuove e le pubblica.
Future<bool> _pollNotifications() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.hasSupabase) return true;

  // L'isolate di background parte pulito: Supabase va inizializzato qui.
  // La sessione è persistita su disco dal processo principale, quindi
  // `initialize` la ritrova e le query passano la RLS come l'utente loggato.
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return true; // nessuno loggato: niente da mostrare

  final prefs = await SharedPreferences.getInstance();
  final cursor = DateTime.tryParse(prefs.getString(_cursorKey) ?? '');

  var query = client
      .from('notifications')
      .select('id, title, body, link, created_at')
      .eq('user_id', userId)
      .isFilter('read_at', null);
  if (cursor != null) {
    query = query.gt('created_at', cursor.toUtc().toIso8601String());
  }

  final rows = await query
      .order('created_at', ascending: false)
      .limit(_maxPerRun);
  if (rows.isEmpty) return true;

  // Dalla più vecchia alla più recente, così nel centro notifiche l'ordine
  // di lettura è quello naturale.
  for (final row in rows.reversed) {
    final id = row['id']?.toString();
    if (id == null) continue;
    await NotificationService.instance.showRaw(
      id: notificationIdOf(id),
      title: row['title']?.toString() ?? 'Kickly',
      body: row['body']?.toString() ?? '',
      link: row['link']?.toString(),
    );
  }

  // La prima riga è la più recente: diventa il nuovo cursore.
  final newest = DateTime.tryParse(rows.first['created_at']?.toString() ?? '');
  if (newest != null) await markNotificationsSeen(newest);

  return true;
}
