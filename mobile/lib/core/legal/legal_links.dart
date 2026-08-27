import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// PLACEHOLDER DA SOSTITUIRE PRIMA DELLA SUBMISSION: dominio di produzione
/// del sito Next.js dove vivono le pagine legali (src/app/privacy/page.tsx,
/// src/app/terms/page.tsx). Stesso trattamento del placeholder già presente
/// in Info.plist (`REPLACE_WITH_IOS_CLIENT_ID` in `CFBundleURLTypes`, vedi
/// Sezione 4 della spec store-readiness): non è una decisione tecnica che
/// questo piano può prendere al posto del proprietario del progetto, perché
/// dipende dal dominio che verrà effettivamente configurato come
/// `NEXT_PUBLIC_APP_URL` sul deploy di produzione del sito
/// (src/config/site.ts, dove oggi ricade su "http://localhost:3000" in
/// assenza della env var). Finché resta questo valore, i link legali
/// nell'app puntano a un dominio inesistente: sostituirlo con l'URL reale
/// prima di qualunque build inviata agli store.
const _webBaseUrl = 'https://REPLACE_WITH_PRODUCTION_WEB_URL';

/// URL delle pagine legali pubbliche del sito Kickly. Nessuna autenticazione
/// richiesta lato web: raggiungibili anche da un reviewer store senza un
/// account, come richiesto dalla Sezione 3 della spec.
///
/// `abstract final class` (non un enum, non una classe con costruttore
/// privato): è il pattern Dart 3 per un namespace di sole costanti statiche
/// che non deve mai essere istanziato né esteso.
abstract final class LegalLinks {
  static final Uri privacy = Uri.parse('$_webBaseUrl/privacy');
  static final Uri terms = Uri.parse('$_webBaseUrl/terms');
}

/// Apre un link legale nel browser di sistema — mai in una WebView interna
/// all'app: è contenuto legale, l'utente deve poterlo leggere nello stesso
/// browser di cui già si fida per tutto il resto (barra indirizzi visibile,
/// possibilità di copiare il link, gestori di password/traduzione del
/// browser che funzionano normalmente).
///
/// Stesso pattern difensivo di `_call()` in
/// `mobile/lib/features/matches/match_detail_page.dart` (unico altro punto
/// dell'app che already usa `launchUrl`): se il lancio fallisce (nessuna app
/// in grado di aprire http/https, scenario raro ma possibile su un
/// emulatore spoglio) lo segnala con uno SnackBar invece di fallire in
/// silenzio, e controlla `context.mounted` dopo l'`await` perché l'utente
/// potrebbe aver già chiuso la schermata nel frattempo.
Future<void> openLegalUrl(BuildContext context, Uri url) async {
  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile aprire il link.')),
    );
  }
}
