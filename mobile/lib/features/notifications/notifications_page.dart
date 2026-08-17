import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/kickly_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<List<KicklyNotification>>? _future;
  AppState? _appState;
  int _seenRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).repository.getNotifications();
    final state = AppScope.of(context).appState;
    if (!identical(_appState, state)) {
      _appState?.removeListener(_onNotification);
      _appState = state;
      _seenRevision = state.notificationRevision;
      state.addListener(_onNotification);
    }
  }

  void _onNotification() {
    final state = _appState!;
    if (state.notificationRevision == _seenRevision) return;
    _seenRevision = state.notificationRevision;
    _reload();
  }

  @override
  void dispose() {
    _appState?.removeListener(_onNotification);
    super.dispose();
  }

  Future<void> _reload() async {
    // Chiamata anche da _markAll() dopo un await di rete: senza questo
    // controllo, se l'utente lascia la pagina mentre "Leggi tutte" è in
    // corso, AppScope.of(context) qui sotto leggerebbe un context non più
    // valido.
    if (!mounted) return;
    final next = AppScope.of(context).repository.getNotifications();
    // Blocco, non arrow-expression: `() => _future = next` come closure
    // farebbe ritornare a setState() il valore dell'assegnamento, cioè la
    // Future stessa. setState() se ne accorge in debug e lancia *dopo* aver
    // già assegnato il campo ma *prima* di schedulare il rebuild, quindi il
    // resto della funzione (l'`await next` sotto) non gira più: la pagina
    // restava agganciata alla vecchia Future finché qualcos'altro non la
    // ricostruiva per altri motivi.
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _open(KicklyNotification notification) async {
    if (notification.readAt == null) {
      try {
        await AppScope.of(context).repository
            .markNotificationRead(notification.id);
      } catch (_) {
        // Segnare come letta è un dettaglio: se fallisce (rete assente)
        // l'utente deve poter aprire comunque la notifica invece di
        // restare bloccato su un tap che sembra non fare nulla.
      }
    }
    if (!mounted) return;
    final link = notification.link;
    if (link != null && link.startsWith('/')) {
      // `push` restituisce una Future che si completa solo quando l'utente
      // torna indietro dalla pagina di destinazione: attenderla terrebbe
      // `_open` appesa per tutta la visita. Qui la navigazione è l'ultimo
      // passo del metodo, quindi è un fire-and-forget voluto.
      unawaited(context.push(link));
    } else {
      await _reload();
    }
  }

  Future<void> _markAll() async {
    // Azzerare le non lette cambia lo stato dell'utente (la campanella nella
    // shell si spegne), quindi merita il riscontro tattile: la regola del
    // progetto è haptics solo sulle azioni che cambiano stato, mai sui tap di
    // navigazione. `unawaited` perché la vibrazione è un effetto collaterale
    // sul motore aptico e attenderla ritarderebbe la chiamata di rete.
    unawaited(HapticFeedback.lightImpact());
    try {
      await AppScope.of(context).repository.markAllNotificationsRead();
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Il FutureBuilder avvolge l'intero Scaffold, non solo il body: serve a
    // sapere quante non lette ci sono *prima* di costruire la AppBar, perché
    // "Leggi tutte" deve sparire quando non c'è niente da leggere. Con il
    // FutureBuilder dentro al body quel conteggio non era raggiungibile e il
    // pulsante restava lì anche a lista vuota, promettendo un'azione che non
    // avrebbe fatto nulla.
    return FutureBuilder<List<KicklyNotification>>(
      future: _future,
      builder: (context, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        final notifications = snapshot.data ?? const <KicklyNotification>[];
        final unread = notifications
            .where((item) => item.readAt == null)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifiche'),
            actions: [
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton.icon(
                    onPressed: _markAll,
                    // Deliberatamente NON verde, benché il tema colori di
                    // default i TextButton con il primario: in questa vista
                    // l'accento è già assegnato alle notifiche non lette (v.
                    // _NotificationCard). Se si accendesse anche la voce
                    // della AppBar, l'occhio avrebbe due poli e nessuno dei
                    // due risalterebbe. Il pulsante resta comunque evidente
                    // perché compare solo quando serve davvero.
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.foreground,
                    ),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Leggi tutte'),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _body(context, snapshot, loaded, notifications),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncSnapshot<List<KicklyNotification>> snapshot,
    bool loaded,
    List<KicklyNotification> notifications,
  ) {
    if (!loaded) return const ListSkeleton(items: 3);

    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EmptyState(
            icon: Icons.cloud_off,
            title: 'Notifiche non disponibili',
            body: friendlyError(snapshot.error!),
            action: FilledButton(
              onPressed: _reload,
              child: const Text('Riprova'),
            ),
          ),
        ],
      );
    }

    if (notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EmptyState(
            icon: Icons.notifications_none,
            title: 'Tutto tranquillo',
            body:
                'Qui arrivano convocazioni, risultati e novità delle tue leghe. '
                'Per ora non c’è niente da leggere.',
            // Un vuoto senza via d'uscita è un vicolo cieco: da qui l'unico
            // passo sensato è andare dove le notifiche si generano, cioè le
            // partite. `go` e non `push` perché /matches è una tab della
            // shell, mentre questa pagina è stata aperta sopra di essa.
            action: OutlinedButton.icon(
              onPressed: () => context.go('/matches'),
              icon: const Icon(Icons.sports_soccer, size: 18),
              label: const Text('Vai alle partite'),
            ),
          ),
        ],
      );
    }

    // `DateTime.now()` letto una volta sola e passato a tutte le card: se ogni
    // riga lo rileggesse, due notifiche dello stesso identico istante
    // potrebbero finire in gruppi diversi a cavallo della mezzanotte.
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: _groupedEntries(notifications, now),
    );
  }

  /// Intercala le card con le intestazioni di gruppo temporale.
  ///
  /// La lista arriva dal repository già ordinata per data decrescente
  /// (`order('created_at', ascending: false)`), quindi qui basta inserire un
  /// titolo ogni volta che l'etichetta cambia: nessun riordino, nessuna
  /// assunzione in più.
  ///
  /// Perché raggrupparle: le notifiche arrivano a raffiche (una partita creata
  /// ne genera diverse nello stesso minuto), quindi senza intestazioni la
  /// pagina è un muro di card uguali in cui non si capisce dove finisce
  /// "stamattina" e dove comincia "la settimana scorsa". Con i gruppi si
  /// scorre per periodo e ci si ferma dove serve. Il timestamp per riga resta
  /// comunque: l'intestazione esce dallo schermo quando si scorre, la card no.
  List<Widget> _groupedEntries(
    List<KicklyNotification> notifications,
    DateTime now,
  ) {
    final children = <Widget>[];
    String? lastBucket;
    for (final item in notifications) {
      final bucket = _dayBucket(item.createdAt, now);
      if (bucket != lastBucket) {
        if (lastBucket != null) children.add(const SizedBox(height: 6));
        children.add(_DateGroupHeader(label: bucket));
        lastBucket = bucket;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _NotificationCard(
            notification: item,
            now: now,
            onTap: () => _open(item),
          ),
        ),
      );
    }
    return children;
  }
}

/// Card di una singola notifica.
///
/// La distinzione letta/non letta è il cuore di questa pagina, e prima era
/// affidata a tre segnali verdi contemporanei (pallino, icona tinta, cerchio
/// dell'avatar) più il peso del font. Tre accenti nella stessa riga non
/// sommano leggibilità: la diluiscono, perché niente risalta più di niente.
/// Qui il verde resta su UN solo elemento — l'avatar — e la differenza viene
/// rinforzata da due segnali che non dipendono dal colore, quindi leggibili
/// anche da chi non distingue il verde:
///
///  1. il *tono della card*: la non letta sta sulla superficie rialzata
///     (`surfaceHigh`), la letta su quella normale. Si percepisce scorrendo,
///     senza leggere una parola;
///  2. il *contrasto del testo*: titolo bianco e pesante quando è da leggere,
///     grigio e più leggero quando è già stata aperta — è il modo in cui una
///     notifica letta "si spegne" invece di sparire.
///
/// Il pallino verde di prima è stato tolto proprio perché era il terzo segnale
/// ridondante: diceva la stessa cosa dell'avatar, occupando spazio nella riga
/// del titolo (che con nomi lunghi serve tutto al titolo).
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final KicklyNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  /// Vero se il tap porta da qualche parte: stessa condizione usata da
  /// `_open`, così il chevron non promette una navigazione che non avverrà.
  bool get _hasDestination {
    final link = notification.link;
    return link != null && link.startsWith('/');
  }

  @override
  Widget build(BuildContext context) {
    final unread = notification.readAt == null;

    return Card(
      color: unread ? AppTheme.surfaceHigh : AppTheme.surface,
      child: InkWell(
        onTap: onTap,
        // Raggio dal token del tema, non più un 20 scritto a mano: con un
        // valore diverso da quello della Card l'onda del tocco usciva dagli
        // angoli arrotondati che dovrebbero contenerla.
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                // L'unico elemento acceso della riga.
                backgroundColor: unread
                    ? AppTheme.primary.withValues(alpha: .16)
                    : AppTheme.surfaceHigh,
                child: Icon(
                  _iconFor(notification.type),
                  size: 20,
                  color: unread ? AppTheme.primary : AppTheme.mutedSoft,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      // I titoli contengono testo scritto dagli utenti (nomi
                      // di lega e di partita): senza limite, un nome lungo
                      // spingerebbe fuori il chevron e sfonderebbe la card.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        color: unread ? AppTheme.foreground : AppTheme.muted,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: unread ? AppTheme.muted : AppTheme.mutedSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _timeLabel(notification.createdAt, now),
                      style: const TextStyle(
                        color: AppTheme.mutedSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Solo dove il tap porta davvero da qualche parte: sulle
              // notifiche puramente informative il chevron sarebbe una
              // promessa non mantenuta.
              if (_hasDestination) ...[
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.mutedSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Titolo di sezione leggero per i raggruppamenti temporali della lista.
///
/// Non è un [SectionTitle]: quello è pensato per l'intestazione di un'intera
/// pagina (grande, con eyebrow) mentre questo si ripete più volte nella stessa
/// schermata, quindi deve restare defilato e non competere con le card. Stessa
/// forma usata nella pagina Partite; è duplicato e non condiviso perché sta in
/// un widget privato di quel file e `core/widgets/common.dart` è fuori dai
/// file in carico a questa passata.
class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 9, left: 2),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    ),
  );
}

/// Etichetta del gruppo a cui appartiene una notifica, relativa a [now].
///
/// I controlli sono in cascata e non si sovrappongono: quando si arriva a
/// "Questa settimana", oggi e ieri sono già stati intercettati sopra, quindi
/// quel gruppo contiene davvero solo i giorni precedenti a ieri.
String _dayBucket(DateTime when, DateTime now) {
  // Confronto fra date "a mezzanotte" e non fra istanti: una notifica delle
  // 23:50 di ieri dista meno di 24 ore ma resta comunque di *ieri*, ed è così
  // che la legge una persona.
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Oggi';
  if (diff == 1) return 'Ieri';
  if (diff <= 7) return 'Questa settimana';
  if (day.month == today.month && day.year == today.year) return 'Questo mese';
  return _monthLabel(when);
}

/// Timestamp leggibile: relativo quando è recente, assoluto quando non lo è.
///
/// Prima era sempre "12 mar · 18:30", una data grezza che costringe a fare il
/// calcolo a mente proprio nel caso più frequente ("è successo adesso o
/// stamattina?"). Sotto le 24 ore la forma relativa risponde da sola; sopra,
/// la data assoluta torna a essere l'informazione più utile e il formato
/// relativo diventerebbe illeggibile ("da 37 giorni").
String _timeLabel(DateTime when, DateTime now) {
  final elapsed = now.difference(when);

  // Il ramo `< 1` copre anche gli scarti negativi: se l'orologio del telefono
  // è indietro rispetto al server, `createdAt` può risultare nel futuro e
  // senza questo caso si leggerebbe "-3 min fa".
  if (elapsed.inMinutes < 1) return 'Adesso';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min fa';
  if (elapsed.inHours < 24) {
    return elapsed.inHours == 1 ? '1 ora fa' : '${elapsed.inHours} ore fa';
  }

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final days = today.difference(day).inDays;
  if (days == 1) return 'Ieri, ${DateFormat('HH:mm').format(when)}';
  // Entro la settimana il nome del giorno ("Martedì, 21:15") si colloca
  // meglio di una data numerica, che a quella distanza va ancora decodificata.
  if (days <= 6) {
    return _capitalize(DateFormat('EEEE, HH:mm', 'it_IT').format(when));
  }
  if (when.year == now.year) {
    return DateFormat('d MMM · HH:mm', 'it_IT').format(when);
  }
  // Oltre l'anno l'ora non serve più a nessuno, l'anno sì.
  return DateFormat('d MMM y', 'it_IT').format(when);
}

/// "marzo 2026" -> "Marzo 2026": in locale it_IT `DateFormat` restituisce mesi
/// e giorni in minuscolo, ma qui servono come intestazioni.
String _monthLabel(DateTime date) =>
    _capitalize(DateFormat('MMMM y', 'it_IT').format(date));

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Icona per famiglia di notifica: dà alla lista un ritmo visivo, così si
/// riconosce di cosa parla una riga prima ancora di leggerla.
IconData _iconFor(String type) {
  if (type.contains('match') || type == 'reminder') return Icons.sports_soccer;
  if (type.contains('mvp')) return Icons.emoji_events_outlined;
  if (type.contains('rating')) return Icons.trending_up;
  if (type.contains('league')) return Icons.shield_outlined;
  return Icons.notifications_outlined;
}
