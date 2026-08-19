import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

/// Esito di un tentativo di scrittura sul calendario.
///
/// Esiste per il percorso MANUALE, non per quello automatico: quando è
/// l'utente a chiedere esplicitamente "aggiungi al calendario" ha diritto di
/// sapere com'è andata, e i tre modi in cui può non andare (permesso negato,
/// nessun calendario scrivibile, plugin che fallisce) richiedono tre risposte
/// diverse — solo la prima si risolve dalle impostazioni del telefono, e non
/// avrebbe senso suggerirla per le altre due.
enum CalendarSyncOutcome {
  /// Evento creato o aggiornato: l'id è stato salvato.
  added,

  /// Il sistema operativo non ha concesso l'accesso al calendario.
  permissionDenied,

  /// Il dispositivo non espone nessun calendario su cui si possa scrivere
  /// (tipico degli emulatori appena creati, ma anche di un telefono con i
  /// soli calendari in sola lettura di un abbonamento).
  noWritableCalendar,

  /// Il plugin ha risposto con un errore, o non ha restituito l'id
  /// dell'evento appena scritto.
  pluginError,
}

/// Sincronizza la presenza a una partita col calendario di sistema
/// (iCloud/Apple Calendar su iOS, quello collegato — spesso Google — su
/// Android): "vado" crea o aggiorna l'evento, ogni altra risposta lo toglie.
///
/// Il pacchetto `device_calendar` scrive sul calendario del telefono, non su
/// un account Google via OAuth: se l'utente ha collegato Google Calendar
/// nelle impostazioni di sistema, l'evento arriva comunque lì, senza che
/// Kickly debba gestire consenso o token di Google per conto proprio.
///
/// Ogni chiamata è avvolta perché la sincronizzazione col calendario non
/// deve MAI far fallire la conferma di presenza: è un arricchimento, non il
/// dato che conta. Se il permesso è negato o il dispositivo non ha un
/// calendario scrivibile, la partita resta comunque confermata su Kickly.
class MatchCalendarService {
  MatchCalendarService({DeviceCalendarPlugin? plugin})
    : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  static const _prefsKeyPrefix = 'calendar_event_';

  /// Le partite qui durano un'ora e mezza per convenzione: non c'è un orario
  /// di fine registrato da nessuna parte (le partite amatoriali non lo
  /// dichiarano quasi mai), e 90 minuti è la stima più comune per un 5v5-11v11
  /// incluso il tempo di ritrovo, più realistica di un evento a durata zero
  /// che in molti calendari si vede a malapena.
  static const _assumedDuration = Duration(minutes: 90);

  Future<void> syncForResponse(MatchSummary match, String response) async {
    try {
      if (response == 'going') {
        // L'esito si scarta di proposito: qui nessun fallimento deve
        // arrivare all'utente (vedi doc della classe). A leggerlo è solo
        // addManually, dove è l'utente stesso ad aver chiesto l'aggiunta.
        await _addOrUpdate(match);
      } else {
        await _remove(match.id);
      }
    } catch (error, stack) {
      // Silenzioso di proposito (vedi doc della classe): un fallimento qui
      // non deve interrompere né mascherare il successo della RSVP, già
      // confermata al chiamante prima che questo metodo venga invocato.
      debugPrint('Sincronizzazione calendario non riuscita: $error\n$stack');
    }
  }

  /// Aggiunge la partita al calendario su richiesta esplicita dell'utente,
  /// restituendo l'esito invece di ingoiarlo.
  ///
  /// È il gemello "parlante" di [syncForResponse], e serve a due casi che il
  /// percorso automatico non copre per costruzione:
  /// 1. chi aveva già confermato la presenza PRIMA che la sincronizzazione
  ///    automatica esistesse non la vedrà mai scattare, perché si aggancia
  ///    all'atto di rispondere: senza un'azione manuale non avrebbe nessun
  ///    modo di recuperare la partita nel proprio calendario;
  /// 2. quando l'automatismo fallisce resta muto di proposito (non deve
  ///    disturbare una RSVP andata a buon fine), quindi oggi un permesso
  ///    negato è indistinguibile da un successo.
  ///
  /// Non solleva mai: il chiamante nella UI deve poter mappare l'esito su un
  /// messaggio senza avvolgere la chiamata in un altro try.
  Future<CalendarSyncOutcome> addManually(MatchSummary match) async {
    try {
      return await _addOrUpdate(match);
    } catch (error, stack) {
      debugPrint('Aggiunta manuale al calendario non riuscita: $error\n$stack');
      return CalendarSyncOutcome.pluginError;
    }
  }

  /// Dice se questa partita risulta già scritta sul calendario.
  ///
  /// Si basa sull'id salvato al momento della scrittura, non su una lettura
  /// del calendario: interrogare il calendario richiederebbe il permesso, e
  /// chiederlo solo per disegnare un'etichetta significherebbe mostrare il
  /// dialogo di sistema all'apertura della pagina, prima ancora che l'utente
  /// abbia chiesto qualcosa.
  Future<bool> isSynced(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefsKeyPrefix$matchId') != null;
  }

  /// Corpo condiviso dai due percorsi: torna sempre un esito, che
  /// [syncForResponse] scarta (resta silenzioso come prima) e [addManually]
  /// invece mostra. Tenerlo unico evita che il percorso manuale e quello
  /// automatico divergano alla prima modifica alla logica di scrittura.
  Future<CalendarSyncOutcome> _addOrUpdate(MatchSummary match) async {
    if (!await _ensurePermission()) return CalendarSyncOutcome.permissionDenied;
    final calendarId = await _writableCalendarId();
    if (calendarId == null) return CalendarSyncOutcome.noWritableCalendar;

    final prefs = await SharedPreferences.getInstance();
    final storedKey = '$_prefsKeyPrefix${match.id}';
    // eventId esistente passato di nuovo a createOrUpdateEvent: senza,
    // ripetere "Vado" dopo un cambio idea creerebbe un secondo evento
    // invece di aggiornare quello già lì.
    final existingEventId = prefs.getString(storedKey);

    final event =
        Event(
            calendarId,
            eventId: existingEventId,
            title: match.title,
            start: match.startsAt,
            end: match.startsAt.add(_assumedDuration),
            startTimeZone: 'Europe/Rome',
            endTimeZone: 'Europe/Rome',
            description: '${match.leagueName} · Kickly',
          )
          ..location = match.locationName.isEmpty
              ? match.city
              : '${match.locationName}, ${match.city}'
          // Obbligatorio su Android, non decorativo: lasciandolo null il
          // plugin scrive NULL in Events.availability, che ha un vincolo NOT
          // NULL nel CalendarProvider. L'inserimento sopravvive (il provider
          // applica il suo default), l'AGGIORNAMENTO no: fallisce con
          // SQLITE_CONSTRAINT_NOTNULL. Si vede solo riaggiungendo una partita
          // già in calendario, ed è il motivo per cui va impostato qui —
          // verificato su emulatore, il log lo mostrava mentre la UI no.
          // "Busy" è anche la semantica giusta: a una partita confermata ci
          // sei, e chi guarda la tua disponibilità deve vederti occupato.
          ..availability = Availability.Busy;

    final result = await _plugin.createOrUpdateEvent(event);
    final newEventId = result?.data;
    if (result?.isSuccess == true && newEventId != null) {
      await prefs.setString(storedKey, newEventId);
      return CalendarSyncOutcome.added;
    }
    // Senza id non c'è niente da salvare, e soprattutto non c'è prova che
    // l'evento sia stato scritto: dichiararlo aggiunto qui farebbe apparire
    // all'utente un "fatto" per un evento che nel calendario non c'è.
    return CalendarSyncOutcome.pluginError;
  }

  Future<void> _remove(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = '$_prefsKeyPrefix$matchId';
    final eventId = prefs.getString(storedKey);
    // Niente da togliere: la partita non era mai stata "andata", oppure il
    // permesso calendario non era mai stato concesso quando fu accettata.
    // Uscire silenziosamente qui è il comportamento giusto, non un errore.
    if (eventId == null) return;
    final calendarId = await _writableCalendarId();
    // La chiave si dimentica SOLO se l'evento è stato davvero cancellato.
    // Se il permesso è stato revocato nel frattempo (calendarId null) o il
    // plugin fallisce, l'evento resta nel calendario: perdere qui l'id
    // renderebbe quell'evento orfano per sempre, senza più modo di
    // ritrovarlo a un tentativo successivo.
    if (calendarId == null) return;
    final result = await _plugin.deleteEvent(calendarId, eventId);
    // isSuccess da solo non basta: guarda solo che `data` non sia null,
    // quindi un `data: false` legittimo (cancellazione rifiutata, non un
    // errore) risulterebbe "successo". Stesso controllo doppio già usato
    // sopra in _ensurePermission per lo stesso identico motivo.
    if (result.isSuccess && result.data == true) await prefs.remove(storedKey);
  }

  Future<bool> _ensurePermission() async {
    final hasPermission = await _plugin.hasPermissions();
    if (hasPermission.isSuccess && hasPermission.data == true) return true;
    // Se l'utente ha già negato in passato, iOS e Android non ripropongono
    // il dialogo: requestPermissions() torna false all'istante, senza
    // infastidire con un prompt che il sistema operativo non mostrerebbe
    // comunque. Nessuna logica di "non richiedere più" da tenere qui.
    final requested = await _plugin.requestPermissions();
    return requested.isSuccess && requested.data == true;
  }

  Future<String?> _writableCalendarId() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return null;
    final calendars = result.data!.where((c) => c.isReadOnly != true).toList();
    if (calendars.isEmpty) return null;
    final preferred = calendars.where((c) => c.isDefault == true).firstOrNull;
    return (preferred ?? calendars.first).id;
  }
}
