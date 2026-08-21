// In modalità demo (client: null) queste due chiamate non devono mai
// toccare la rete: KicklyRepository(client: null) è lo stesso pattern già
// usato nei test esistenti (story_onboarding_test.dart) per esercitare il
// codice senza un Supabase reale.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/data/kickly_repository.dart';

void main() {
  group('KicklyRepository — cancellazione account, modalità demo', () {
    test(
      'getAccountDeletionBlockers non chiama la rete e restituisce lista vuota',
      () async {
        final repository = KicklyRepository(client: null);

        final blockers = await repository.getAccountDeletionBlockers();

        expect(blockers, isEmpty);
      },
    );

    test(
      'deleteAccount è un no-op che completa senza lanciare eccezioni',
      () async {
        final repository = KicklyRepository(client: null);

        await expectLater(repository.deleteAccount(), completes);
      },
    );
  });
}
