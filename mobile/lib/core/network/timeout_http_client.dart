import 'package:http/http.dart' as http;

/// Applica un timeout esplicito a ogni richiesta HTTP fatta dal client
/// Supabase (REST, RPC, Storage, Auth passano tutti da qui).
///
/// Senza questo wrapper, nessuna chiamata di rete nell'app aveva un timeout
/// esplicito: su una rete capitiva o assente lo spinner di caricamento gira
/// per la durata (spesso lunghissima o indefinita) del timeout di sistema,
/// invece di fallire in fretta con un messaggio chiaro. `friendlyError` in
/// `core/widgets/common.dart` già gestisce il messaggio generico per
/// qualunque eccezione non riconosciuta, incluso `TimeoutException`: qui
/// serve solo garantire che quell'eccezione arrivi in un tempo ragionevole.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 15)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() => _inner.close();
}
