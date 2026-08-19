import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

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

  Future<void> _addOrUpdate(MatchSummary match) async {
    if (!await _ensurePermission()) return;
    final calendarId = await _writableCalendarId();
    if (calendarId == null) return;

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
              : '${match.locationName}, ${match.city}';

    final result = await _plugin.createOrUpdateEvent(event);
    final newEventId = result?.data;
    if (result?.isSuccess == true && newEventId != null) {
      await prefs.setString(storedKey, newEventId);
    }
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
    if (calendarId != null) {
      await _plugin.deleteEvent(calendarId, eventId);
    }
    await prefs.remove(storedKey);
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
