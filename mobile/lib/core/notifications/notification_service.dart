import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models.dart';
import '../theme/app_theme.dart';

/// Mostra le notifiche Kickly come banner di sistema.
///
/// Prima l'app poteva solo far comparire una SnackBar dentro la schermata
/// aperta: se eri su un'altra app, o l'app era in background, la notifica non
/// esisteva. Qui usiamo il canale locale del sistema operativo, che consegna un
/// vero banner e lascia la notifica nel centro notifiche del telefono.
///
/// Questo canale copre app in primo piano e in background. Il caso "app chiusa"
/// è coperto dal task periodico in `background_sync.dart`.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Link della notifica toccata mentre l'app era chiusa.
  ///
  /// Al lancio da notifica il router non esiste ancora, quindi il link resta
  /// qui e viene consumato da `takePendingLink()` appena la navigazione è
  /// pronta.
  String? _pendingLink;

  /// Callback di navigazione registrata dall'app una volta creato il router.
  void Function(String link)? _onOpenLink;

  /// Canale Android su cui vengono pubblicate le notifiche.
  ///
  /// `high` fa comparire il banner a schermo; con `defaultImportance` Android
  /// la metterebbe in sordina nel cassetto.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'kickly_notifications',
    'Kickly',
    description: 'Partite, formazioni, promemoria e novità delle tue leghe.',
    importance: Importance.high,
  );

  /// Prepara il plugin e recupera un eventuale avvio da notifica.
  ///
  /// Va chiamato prima di `runApp` così che il link di lancio sia già
  /// disponibile quando il router fa il primo redirect.
  Future<void> initialize() async {
    if (_ready) return;

    const settings = InitializationSettings(
      // Icona di stato dedicata (drawable/ic_stat_kickly, silhouette bianca
      // trasparente della "K"), non l'icona a colori dell'app: Android
      // pretende un monocromatico per la status bar e sagoma da solo
      // qualunque altra cosa gli si passi, di norma male.
      android: AndroidInitializationSettings('ic_stat_kickly'),
      iOS: DarwinInitializationSettings(
        // I permessi li chiediamo dopo il login, non al primo avvio: chiederli
        // sulla schermata di accesso significa quasi sempre un "non consentire".
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) =>
          _handleLink(response.payload),
      // Tap gestito mentre l'app è terminata: il sistema riavvia l'isolate.
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // L'app può essere stata aperta proprio toccando una notifica: in quel caso
    // il link va onorato dopo il primo frame.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _pendingLink = launch?.notificationResponse?.payload;
    }

    _ready = true;
  }

  /// Chiede il permesso di mostrare notifiche.
  ///
  /// Su Android 13+ e su iOS senza questo consenso il banner non compare. Va
  /// chiamato dopo il login, quando il motivo per cui serve è evidente.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Registra chi deve gestire l'apertura di un link di notifica.
  ///
  /// Se c'era un link in sospeso (app aperta dalla notifica) viene consegnato
  /// subito.
  void bindNavigation(void Function(String link) onOpenLink) {
    _onOpenLink = onOpenLink;
    final pending = takePendingLink();
    if (pending != null) onOpenLink(pending);
  }

  /// Restituisce e azzera il link di lancio in sospeso.
  String? takePendingLink() {
    final link = _pendingLink;
    _pendingLink = null;
    return link;
  }

  void _handleLink(String? payload) {
    if (payload == null || !payload.startsWith('/')) return;
    final open = _onOpenLink;
    if (open == null) {
      // Router non ancora pronto: teniamo il link per quando lo sarà.
      _pendingLink = payload;
      return;
    }
    open(payload);
  }

  /// Pubblica una notifica di sistema.
  ///
  /// L'id numerico deriva dall'uuid della notifica, così la stessa riga di
  /// `notifications` non genera due banner se arriva sia da Realtime sia dal
  /// controllo periodico in background.
  Future<void> show(KicklyNotification notification) => showRaw(
    id: notificationIdOf(notification.id),
    title: notification.title,
    body: notification.body,
    link: notification.link,
  );

  /// Variante usabile anche dall'isolate di background, che non costruisce
  /// modelli ma legge righe grezze.
  Future<void> showRaw({
    required int id,
    required String title,
    required String body,
    String? link,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          // `importance`/`priority` duplicano quanto già impostato sul canale:
          // dal Oreo (API 26) in poi è il canale a comandare, ma questi due
          // campi restano l'unico modo per farlo funzionare anche sulle
          // versioni di Android precedenti, dove i canali non esistono.
          // Restiamo su `high` (banner + suono) e non `max`: nessuna delle
          // notifiche Kickly è così urgente da giustificare l'interruzione
          // "a tutto schermo" che Android riserva alla priorità massima.
          importance: Importance.high,
          priority: Priority.high,
          // Verde Kickly: preso da AppTheme invece di ripetere l'esadecimale,
          // così se il brand color cambia non resta disallineato qui.
          color: AppTheme.primary,
          // Il corpo può superare la riga singola: così resta leggibile aperto.
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // Raggruppa i banner Kickly in un unico thread nel Centro
          // Notifiche di iOS invece di lasciarli sparsi: stesso effetto del
          // canale unico su Android, ottenuto qui riusando lo stesso id.
          threadIdentifier: _channel.id,
        ),
      ),
      payload: link,
    );
  }
}

/// Id stabile e positivo a 31 bit ricavato dall'uuid della notifica.
///
/// Android richiede un int: usando sempre lo stesso id per la stessa notifica
/// il sistema la sostituisce invece di impilarne due copie.
int notificationIdOf(String uuid) => uuid.hashCode & 0x7fffffff;

/// Gestore del tap su notifica quando l'app non è in esecuzione.
///
/// Deve essere una funzione top-level annotata, perché il sistema la invoca in
/// un isolate separato che non vede lo stato dell'app.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Il link viene comunque riletto da `getNotificationAppLaunchDetails()` al
  // riavvio dell'app, quindi qui non c'è altro da fare.
  debugPrint('Notifica toccata in background: ${response.payload}');
}

/// Serializza un payload aggiuntivo se in futuro servisse portare più dati del
/// solo link (per esempio l'id partita) dentro la notifica.
String encodePayload(Map<String, Object?> data) => jsonEncode(data);
