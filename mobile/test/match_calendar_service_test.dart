import 'dart:collection';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/core/calendar/match_calendar_service.dart';
import 'package:kickly_app/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sostituisce le chiamate reali a EventKit/CalendarContract con risposte
/// programmabili. DeviceCalendarPlugin() è un singleton (vedi il sorgente
/// del pacchetto: la factory pubblica restituisce sempre la stessa
/// istanza), quindi il doppio passa dal costruttore `.private()`,
/// annotato @visibleForTesting proprio per questo, invece che dal
/// costruttore normale.
class _FakeDeviceCalendarPlugin extends DeviceCalendarPlugin {
  _FakeDeviceCalendarPlugin() : super.private();

  bool permissionGranted = true;
  bool deleteSucceeds = true;
  List<Calendar> calendars = [
    Calendar(id: 'cal-1', isReadOnly: false, isDefault: true),
  ];
  String createdEventId = 'evt-nuovo';

  int createOrUpdateCalls = 0;
  int deleteCalls = 0;
  Event? lastEvent;
  String? lastDeletedEventId;

  @override
  Future<Result<bool>> hasPermissions() async => Result<bool>()..data = false;

  @override
  Future<Result<bool>> requestPermissions() async =>
      Result<bool>()..data = permissionGranted;

  @override
  Future<Result<UnmodifiableListView<Calendar>>> retrieveCalendars() async =>
      Result<UnmodifiableListView<Calendar>>()
        ..data = UnmodifiableListView(calendars);

  @override
  Future<Result<String>?> createOrUpdateEvent(Event? event) async {
    createOrUpdateCalls++;
    lastEvent = event;
    return Result<String>()..data = createdEventId;
  }

  @override
  Future<Result<bool>> deleteEvent(String? calendarId, String? eventId) async {
    deleteCalls++;
    lastDeletedEventId = eventId;
    return Result<bool>()..data = deleteSucceeds;
  }
}

MatchSummary _match({String id = 'm1', String locationName = 'Campo Sud'}) =>
    MatchSummary(
      id: id,
      leagueId: 'l1',
      leagueName: 'Lega Test',
      leagueSlug: 'lega-test',
      title: 'Amichevole del giovedì',
      startsAt: DateTime(2026, 9, 3, 20, 30),
      locationName: locationName,
      city: 'Torino',
      footballFormat: '5v5',
      maxPlayers: 10,
      goingCount: 8,
      status: 'open',
      visibility: 'league_only',
      registrationClosedAt: null,
      currentResponse: 'going',
      isLeagueMember: true,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MatchCalendarService: sincronizzazione con la RSVP', () {
    test('accettare crea un evento con titolo, orario e luogo corretti, e memorizza il suo id', () async {
      final plugin = _FakeDeviceCalendarPlugin();
      final service = MatchCalendarService(plugin: plugin);

      await service.syncForResponse(_match(), 'going');

      expect(plugin.createOrUpdateCalls, 1);
      final event = plugin.lastEvent!;
      expect(event.title, 'Amichevole del giovedì');
      expect(event.start, DateTime(2026, 9, 3, 20, 30));
      // 90 minuti per convenzione: nessuna partita amatoriale dichiara un
      // orario di fine, un evento a durata zero si vede a malapena nei
      // calendari.
      expect(event.end, DateTime(2026, 9, 3, 22));
      expect(event.location, 'Campo Sud, Torino');
      expect(event.eventId, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('calendar_event_m1'), 'evt-nuovo');
    });

    test('senza il nome del campo, il luogo dell\'evento resta comunque leggibile con la sola città', () async {
      final plugin = _FakeDeviceCalendarPlugin();
      final service = MatchCalendarService(plugin: plugin);

      await service.syncForResponse(_match(locationName: ''), 'going');

      expect(plugin.lastEvent!.location, 'Torino');
    });

    test('accettare di nuovo la stessa partita aggiorna l\'evento esistente invece di duplicarlo', () async {
      final plugin = _FakeDeviceCalendarPlugin();
      final service = MatchCalendarService(plugin: plugin);
      final match = _match();

      await service.syncForResponse(match, 'going');
      await service.syncForResponse(match, 'going');

      expect(plugin.createOrUpdateCalls, 2);
      // La seconda chiamata porta l'id salvato dalla prima: è quello che fa
      // sì che il plugin aggiorni l'evento invece di crearne un secondo.
      expect(plugin.lastEvent!.eventId, 'evt-nuovo');
    });

    test(
      'disdire dopo aver accettato toglie l\'evento salvato dal calendario',
      () async {
        final plugin = _FakeDeviceCalendarPlugin();
        final service = MatchCalendarService(plugin: plugin);
        final match = _match();

        await service.syncForResponse(match, 'going');
        await service.syncForResponse(match, 'not_going');

        expect(plugin.deleteCalls, 1);
        expect(plugin.lastDeletedEventId, 'evt-nuovo');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('calendar_event_m1'), isNull);
      },
    );

    test('se la cancellazione dal calendario fallisce, l\'id resta salvato invece di perdere il riferimento all\'evento orfano', () async {
      // Segnalato in revisione: rimuovere sempre la chiave anche quando
      // deleteEvent fallisce renderebbe l'evento orfano nel calendario per
      // sempre, senza più modo di ritrovarlo a un tentativo successivo.
      final plugin = _FakeDeviceCalendarPlugin()..deleteSucceeds = false;
      final service = MatchCalendarService(plugin: plugin);
      final match = _match();

      await service.syncForResponse(match, 'going');
      await service.syncForResponse(match, 'not_going');

      expect(plugin.deleteCalls, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('calendar_event_m1'), 'evt-nuovo');
    });

    test('disdire una partita mai accettata non tocca il calendario: non c\'era niente da togliere', () async {
      final plugin = _FakeDeviceCalendarPlugin();
      final service = MatchCalendarService(plugin: plugin);

      await service.syncForResponse(_match(), 'not_going');

      expect(plugin.deleteCalls, 0);
    });

    test('permesso negato: la sincronizzazione si ferma senza creare l\'evento né sollevare un errore', () async {
      final plugin = _FakeDeviceCalendarPlugin()..permissionGranted = false;
      final service = MatchCalendarService(plugin: plugin);

      await expectLater(service.syncForResponse(_match(), 'going'), completes);
      expect(plugin.createOrUpdateCalls, 0);
    });

    test('nessun calendario scrivibile sul dispositivo: nessuna chiamata, nessun errore', () async {
      final plugin = _FakeDeviceCalendarPlugin()
        ..calendars = [Calendar(id: 'cal-ro', isReadOnly: true)];
      final service = MatchCalendarService(plugin: plugin);

      await expectLater(service.syncForResponse(_match(), 'going'), completes);
      expect(plugin.createOrUpdateCalls, 0);
    });
  });
}
