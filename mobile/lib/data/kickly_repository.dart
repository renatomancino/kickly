import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/notifications/background_sync.dart';
import '../core/notifications/notification_service.dart';
import '../core/security/oauth_nonce.dart';
import 'demo_data.dart';
import 'models.dart';

class KicklyRepository {
  KicklyRepository({required this.client});

  final SupabaseClient? client;

  bool get isDemo => client == null;
  String? get currentUserId => client?.auth.currentUser?.id;
  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    final supabase = client;
    if (supabase == null) return;
    await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    final supabase = client;
    if (supabase == null) return;
    await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConfig.authCallbackUrl,
    );
  }

  Future<void> resetPassword(String email) async {
    final supabase = client;
    if (supabase == null) return;
    await supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.authCallbackUrl,
    );
  }

  /// Accedi con Google: flusso nativo (Play Services su Android, ASWebAuth
  /// su iOS), non un webview con schermata di consenso del browser.
  ///
  /// Richiede `GoogleSignIn.instance.initialize()` già completato
  /// all'avvio dell'app (vedi main.dart) — chiamare questo metodo prima
  /// dell'inizializzazione è un errore del chiamante, non qualcosa da cui
  /// questo metodo può proteggere in modo sensato.
  Future<void> signInWithGoogle() async {
    final supabase = client;
    if (supabase == null) return;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // In pratica non dovrebbe succedere: Google Sign-In restituisce sempre
      // un ID token per un'autenticazione riuscita. Se capita, è più onesto
      // fallire con un messaggio chiaro che proseguire con una sessione a
      // metà.
      throw const AuthException(
        'Google non ha restituito un token valido. Riprova.',
      );
    }
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Accedi con Apple: nativo su iOS/macOS, richiesto dalle linee guida
  /// Apple quando l'app offre anche un altro login social.
  ///
  /// Il nonce protegge dal replay: lo si manda hashato ad Apple, Apple lo
  /// incorpora nell'ID token, e Supabase verifica che l'hash del nonce in
  /// chiaro che gli mandiamo qui corrisponda — un ID token intercettato e
  /// riproposto in un'altra sessione non avrebbe il nonce giusto.
  Future<void> signInWithApple() async {
    final supabase = client;
    if (supabase == null) return;
    final nonce = OAuthNonce.generate();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce.hashed,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Apple non ha restituito un token valido. Riprova.',
      );
    }
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: nonce.raw,
    );
    // Apple manda nome e cognome solo alla primissima autorizzazione fra
    // questo utente e questa app: se non li salviamo ora, il modo per
    // recuperarli è chiedere all'utente di reinserirli a mano, perché Apple
    // non li ripropone più nelle autenticazioni successive. L'onboarding
    // (ProfileEditorPage) mostra comunque i campi nome/cognome per chi non li
    // ha già compilati, quindi qui è solo una precompilazione best-effort,
    // non l'unica via per completare il profilo.
    final firstName = credential.givenName;
    final lastName = credential.familyName;
    if (firstName != null || lastName != null) {
      try {
        final userId = currentUserId;
        if (userId != null) {
          final existing = await supabase
              .from('profiles')
              .select('first_name, last_name')
              .eq('id', userId)
              .maybeSingle();
          final hasName =
              (existing?['first_name'] as String?)?.isNotEmpty == true;
          if (!hasName) {
            await supabase
                .from('profiles')
                .update({'first_name': ?firstName, 'last_name': ?lastName})
                .eq('id', userId);
          }
        }
      } catch (error) {
        // Precompilazione best-effort: se fallisce, l'utente compila comunque
        // il nome in onboarding. Non deve bloccare il login.
        debugPrint('Precompilazione nome da Apple non riuscita: $error');
      }
    }
  }

  Future<void> signOut() async {
    final supabase = client;
    if (supabase == null) return;
    await supabase.auth.signOut();
    // Chiude anche la sessione nativa di Google: senza questo, al prossimo
    // avvio Play Services potrebbe riselezionare in automatico lo stesso
    // account senza mostrare il selettore, e "Esci" da Kickly non
    // corrisponderebbe più a "sei uscito" per l'utente. Se Google Sign-In
    // non è configurato o non è mai stato inizializzato, questa chiamata
    // fallisce e il catch la rende un no-op innocuo.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('Sign out da Google non riuscito: $error');
    }
  }

  /// Leghe che oggi impedirebbero la cancellazione dell'account: il
  /// chiamante ne è owner e ci sono altri membri attivi oltre a lui. La UI
  /// la interroga prima di mostrare la conferma di eliminazione, così può
  /// mostrare subito la schermata "risolvi prima di continuare" invece di
  /// far scoprire il blocco solo dopo un tentativo fallito.
  Future<List<AccountDeletionBlocker>> getAccountDeletionBlockers() async {
    if (isDemo) return const [];
    final data = await client!.rpc('get_account_deletion_blockers');
    return (data as List<dynamic>? ?? const [])
        .map(
          (raw) => AccountDeletionBlocker.fromMap(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList();
  }

  /// Cancella l'account: prima la RPC che anonimizza il profilo (fallisce
  /// con `account_has_blocking_leagues` se ci sono leghe da risolvere),
  /// poi la Edge Function che banna l'account e revoca le sue sessioni —
  /// operazione non raggiungibile da SQL. Se la RPC fallisce con
  /// `account_already_deleted` (profilo gia' anonimizzato da un tentativo
  /// precedente la cui chiamata alla Edge Function non era andata a buon
  /// fine) si prosegue comunque: e' il modo per completare un retry, vedi il
  /// commento nel corpo del metodo. Il chiamante deve poi fare il signOut
  /// locale: questo metodo si occupa solo delle due chiamate di rete, non
  /// della sessione locale (stessa separazione già usata altrove fra
  /// repository e AppState).
  Future<void> deleteAccount() async {
    if (isDemo) return;
    try {
      await client!.rpc('request_account_deletion');
    } catch (error) {
      // Se un tentativo precedente aveva gia' anonimizzato il profilo ma poi
      // la invoke() sotto era fallita (es. un blip di rete), la RPC qui sopra
      // fallisce subito con account_already_deleted perche' quel controllo e'
      // la prima cosa che fa request_account_deletion() (vedi
      // supabase/migrations/20260821090000_account_deletion.sql). Senza
      // questo controllo l'utente resterebbe bloccato: il profilo e' gia'
      // anonimizzato quindi ogni retry ripete lo stesso errore, e non c'e'
      // altro modo lato client per arrivare a bannare l'account. Trattarlo
      // come "anonimizzazione gia' fatta" e proseguire e' sicuro: la RPC e'
      // pura anonimizzazione dati, non ha effetti da rieseguire. Qualunque
      // altro errore (account_has_blocking_leagues, rete, ecc.) deve invece
      // continuare a propagarsi normalmente, stesso idioma di
      // friendlyError() in core/widgets/common.dart.
      if (!error.toString().contains('account_already_deleted')) rethrow;
    }
    await client!.functions.invoke('delete-account');
  }

  Future<void> updatePassword(String password) async {
    if (isDemo) return;
    await client!.auth.updateUser(UserAttributes(password: password));
  }

  Future<UserProfile?> getCurrentProfile() async {
    if (isDemo) return demoProfile;
    final userId = currentUserId;
    if (userId == null) return null;
    final values = await Future.wait<dynamic>([
      client!
          .from('profiles')
          .select(
            'id, username, first_name, last_name, avatar_path, primary_position, '
            'secondary_position, preferred_foot, skill_level, birth_date, city, '
            'province, profile_public, overall, timezone, onboarding_completed',
          )
          .eq('id', userId)
          .maybeSingle(),
      client!
          .from('profile_locations')
          .select('city, province, latitude, longitude')
          .eq('user_id', userId)
          .maybeSingle(),
    ]);
    final row = values[0];
    if (row == null) return null;
    final merged = Map<String, dynamic>.from(row as Map);
    if (values[1] is Map) {
      merged.addAll(Map<String, dynamic>.from(values[1] as Map));
    }
    return _mapProfile(merged);
  }

  Future<void> saveProfile({
    required String username,
    required String firstName,
    required String lastName,
    required String primaryPosition,
    required String skillLevel,
    String? birthDate,
    String? city,
    String? province,
    double? latitude,
    double? longitude,
    String? secondaryPosition,
    String? preferredFoot,
    bool profilePublic = true,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) async {
    if (isDemo) return;
    final userId = currentUserId;
    if (userId == null) throw StateError('Sessione non disponibile.');

    String? avatarPath;
    if (avatarBytes != null) {
      final requested = avatarExtension?.toLowerCase();
      final extension = ['png', 'webp'].contains(requested)
          ? requested!
          : 'jpg';
      avatarPath = '$userId/avatar.$extension';
      await client!.storage
          .from('avatars')
          .uploadBinary(
            avatarPath,
            avatarBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: extension == 'png'
                  ? 'image/png'
                  : extension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg',
            ),
          );
    }

    final payload = <String, dynamic>{
      'id': userId,
      'username': username.trim().toLowerCase(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'primary_position': primaryPosition,
      'secondary_position': secondaryPosition,
      'preferred_foot': preferredFoot ?? 'right',
      'skill_level': skillLevel,
      'birth_date': birthDate?.trim().isEmpty == true ? null : birthDate,
      'city': city?.trim() ?? '',
      'province': province?.trim(),
      'profile_public': profilePublic,
      'onboarding_completed': true,
    };
    if (avatarPath != null) payload['avatar_path'] = avatarPath;
    await client!.from('profiles').upsert(payload, onConflict: 'id');
    if (city?.trim().isNotEmpty == true &&
        province?.trim().isNotEmpty == true &&
        latitude != null &&
        longitude != null) {
      await client!.from('profile_locations').upsert({
        'user_id': userId,
        'city': city!.trim(),
        'province': province!.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    }
  }

  Future<List<LeagueSummary>> getLeagues() async {
    if (isDemo) return demoLeagues;
    final data = await client!.rpc('get_user_league_summaries');
    final leagues = (data as List<dynamic>? ?? const [])
        .map(
          (row) => LeagueSummary.fromRpc(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    leagues.sort((a, b) => a.name.compareTo(b.name));
    return leagues;
  }

  Future<LeagueDetail?> getLeague(String slug) async {
    if (isDemo) {
      final summary = demoLeagues
          .where((item) => item.slug == slug)
          .firstOrNull;
      if (summary == null) return null;
      return LeagueDetail(
        summary: summary,
        ownerId: 'demo-owner',
        inviteCode: 'KICKLY7',
        members: List.generate(
          summary.memberCount.clamp(1, 8),
          (index) => LeagueMember(
            id: 'member-$index',
            userId: index == 0 ? 'demo-user' : 'demo-user-$index',
            username: index == 0 ? 'renato10' : 'player${index + 1}',
            firstName: index == 0 ? 'Renato' : 'Giocatore',
            lastName: index == 0 ? 'Bianchi' : '${index + 1}',
            avatarUrl: null,
            footballRole: [
              'goalkeeper',
              'defender',
              'midfielder',
              'forward',
            ][index % 4],
            leagueRole: index == 0 ? summary.currentUserRole : 'member',
            joinedAt: DateTime.now().subtract(Duration(days: index * 8)),
          ),
        ),
      );
    }

    final raw = await client!
        .rpc('get_league_detail', params: {'target_slug': slug})
        .maybeSingle();
    if (raw == null) return null;
    final row = Map<String, dynamic>.from(raw);
    final summary = LeagueSummary.fromRpc({
      ...row,
      'member_count': (row['members'] as List<dynamic>? ?? const []).length,
    });
    final members = (row['members'] as List<dynamic>? ?? const []).map((item) {
      final member = Map<String, dynamic>.from(item as Map);
      final path = member['avatar_path']?.toString();
      return LeagueMember(
        id: member['id'].toString(),
        userId: member['user_id'].toString(),
        username: member['username']?.toString() ?? 'giocatore',
        firstName: member['first_name']?.toString(),
        lastName: member['last_name']?.toString(),
        avatarUrl: _publicUrl('avatars', path),
        footballRole: member['football_role']?.toString(),
        leagueRole: member['role']?.toString() ?? 'member',
        joinedAt: asDate(member['joined_at']),
      );
    }).toList();
    return LeagueDetail(
      summary: summary,
      ownerId: row['owner_id'].toString(),
      inviteCode: row['invite_code']?.toString() ?? '',
      members: members,
    );
  }

  Future<String> createLeague({
    required String name,
    required String slug,
    required String description,
    required String city,
    required String country,
    required String visibility,
    required String footballFormat,
    required int maxMembers,
    String? province,
    double? latitude,
    double? longitude,
    Uint8List? logoBytes,
    String? logoExtension,
  }) async {
    if (isDemo) return slug;
    final data = await client!.rpc(
      'create_league',
      params: {
        'league_name': name.trim(),
        'league_slug': slug.trim().toLowerCase(),
        'league_description': description.trim(),
        'league_city': city.trim(),
        'league_country': country.trim(),
        'league_visibility': visibility,
        'league_format': footballFormat,
        'league_max_members': maxMembers,
        'league_province': ?province,
        'league_latitude': ?latitude,
        'league_longitude': ?longitude,
      },
    );
    final rows = data as List<dynamic>? ?? const [];
    if (rows.isEmpty) throw StateError('Lega non creata.');
    final created = Map<String, dynamic>.from(rows.first as Map);
    final createdSlug = created['slug'].toString();
    if (logoBytes != null) {
      final id =
          created['id']?.toString() ??
          (await getLeague(createdSlug))?.summary.id;
      if (id != null) await _uploadLeagueLogo(id, logoBytes, logoExtension);
    }
    return createdSlug;
  }

  Future<void> updateLeague({
    required String id,
    required String name,
    required String description,
    required String city,
    required String country,
    required String visibility,
    required String footballFormat,
    required int maxMembers,
    Uint8List? logoBytes,
    String? logoExtension,
  }) async {
    if (isDemo) return;
    final count = await client!
        .from('league_members')
        .count(CountOption.exact)
        .eq('league_id', id)
        .eq('status', 'active');
    if (count > maxMembers) {
      throw StateError('La lega ha già $count membri attivi.');
    }
    final payload = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'city': city.trim(),
      'country': country.trim(),
      'visibility': visibility,
      'football_format': footballFormat,
      'max_members': maxMembers,
    };
    if (logoBytes != null) {
      payload['logo_url'] = await _uploadLeagueLogo(
        id,
        logoBytes,
        logoExtension,
      );
    }
    await client!.from('leagues').update(payload).eq('id', id);
  }

  Future<void> deleteLeague(String id) async {
    if (!isDemo) await client!.from('leagues').delete().eq('id', id);
  }

  Future<String> _uploadLeagueLogo(
    String id,
    Uint8List bytes,
    String? extension,
  ) async {
    final ext = ['png', 'webp'].contains(extension?.toLowerCase())
        ? extension!.toLowerCase()
        : 'jpg';
    final path = '$id/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await client!.storage
        .from('league-logos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png'
                ? 'image/png'
                : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg',
          ),
        );
    return client!.storage.from('league-logos').getPublicUrl(path);
  }

  Future<JsonMap?> getInvitePreview(String code) async {
    if (isDemo) {
      return {
        'id': demoLeagues.first.id,
        'name': demoLeagues.first.name,
        'slug': demoLeagues.first.slug,
        'city': demoLeagues.first.city,
        'country': demoLeagues.first.country,
        'football_format': demoLeagues.first.footballFormat,
        'member_count': demoLeagues.first.memberCount,
        'max_members': demoLeagues.first.maxMembers,
        'already_member': false,
      };
    }
    final data = await client!.rpc(
      'get_league_invite_preview',
      params: {'invite': code.trim().toUpperCase()},
    );
    final rows = data as List<dynamic>? ?? const [];
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
  }

  Future<String> joinLeague(String code) async {
    if (isDemo) return demoLeagues.first.slug;
    final result = await client!.rpc(
      'join_league_by_code',
      params: {'invite': code.trim().toUpperCase()},
    );
    return result.toString();
  }

  Future<String> joinPublicLeague(String leagueId) async {
    if (isDemo) return demoLeagues.first.slug;
    final result = await client!.rpc(
      'join_public_league',
      params: {'target_league': leagueId},
    );
    return result.toString();
  }

  Future<List<LeagueCommunication>> getLeagueCommunications(
    String leagueId,
  ) async {
    if (isDemo) {
      return [
        LeagueCommunication(
          id: 'demo-news',
          matchId: null,
          createdBy: 'demo-user',
          kind: 'announcement',
          title: 'Benvenuti nella lega',
          body: 'Qui trovi avvisi, convocazioni e aggiornamenti degli admin.',
          pinned: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          authorName: 'Renato Bianchi',
          authorUsername: 'renato10',
        ),
      ];
    }
    final rows = await client!
        .from('league_communications')
        .select(
          'id, match_id, created_by, kind, title, body, pinned, created_at',
        )
        .eq('league_id', leagueId)
        .order('pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(50);
    final list = (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final authorIds = list
        .map((e) => e['created_by'].toString())
        .toSet()
        .toList();
    final profileRows = authorIds.isEmpty
        ? <dynamic>[]
        : await client!
              .from('profiles')
              .select('id, first_name, last_name, username, avatar_path')
              .inFilter('id', authorIds);
    final profiles = <String, JsonMap>{
      for (final raw in profileRows)
        (raw as Map)['id'].toString(): Map<String, dynamic>.from(raw),
    };
    return list.map((row) {
      final profile =
          profiles[row['created_by'].toString()] ?? const <String, dynamic>{};
      final name = [
        profile['first_name'],
        profile['last_name'],
      ].whereType<String>().where((e) => e.isNotEmpty).join(' ');
      return LeagueCommunication(
        id: row['id'].toString(),
        matchId: row['match_id']?.toString(),
        createdBy: row['created_by'].toString(),
        kind: row['kind']?.toString() ?? 'announcement',
        title: row['title']?.toString() ?? '',
        body: row['body']?.toString() ?? '',
        pinned: row['pinned'] == true,
        createdAt: asDate(row['created_at']),
        authorName: name.isEmpty
            ? '@${profile['username'] ?? 'giocatore'}'
            : name,
        authorUsername: profile['username']?.toString() ?? 'giocatore',
        authorAvatarUrl: _publicUrl(
          'avatars',
          profile['avatar_path']?.toString(),
        ),
      );
    }).toList();
  }

  Future<void> publishLeagueCommunication(
    String leagueId, {
    required String title,
    required String body,
    required bool pinned,
  }) async {
    if (isDemo) return;
    await client!.rpc(
      'publish_league_communication',
      params: {
        'target_league': leagueId,
        'communication_title': title.trim(),
        'communication_body': body.trim(),
        'communication_pinned': pinned,
      },
    );
  }

  Future<void> deleteLeagueCommunication(String id) async {
    if (isDemo) return;
    await client!.rpc(
      'delete_league_communication',
      params: {'target_communication': id},
    );
  }

  Future<List<LeaderboardPlayer>> getLeagueLeaderboard(String leagueId) async {
    if (isDemo) {
      return demoLeagues.isEmpty
          ? const []
          : List.generate(
              8,
              (i) => LeaderboardPlayer(
                userId: 'demo-$i',
                username: 'player${i + 1}',
                name: i == 0 ? 'Renato Bianchi' : 'Giocatore ${i + 1}',
                matches: 20 - i,
                goals: 14 - i,
                assists: 9 - (i ~/ 2),
                mvp: 4 - (i ~/ 2),
                overall: 82 - i,
              ),
            );
    }
    final data = await client!.rpc(
      'get_league_leaderboard_rows',
      params: {'target_league': leagueId},
    );
    return (data as List<dynamic>? ?? const []).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final name = [
        row['first_name'],
        row['last_name'],
      ].whereType<String>().join(' ').trim();
      return LeaderboardPlayer(
        userId: row['user_id'].toString(),
        username: row['username']?.toString() ?? 'giocatore',
        name: name.isEmpty ? '@${row['username'] ?? 'giocatore'}' : name,
        avatarUrl: _publicUrl('avatars', row['avatar_path']?.toString()),
        matches: asInt(row['matches_played']),
        goals: asInt(row['goals']),
        assists: asInt(row['assists']),
        mvp: asInt(row['mvp_awards']),
        overall: asInt(row['overall'], 70),
      );
    }).toList();
  }

  Future<void> setLeagueMemberRole(
    String leagueId,
    String userId,
    String role,
  ) async {
    if (!isDemo) {
      await client!.rpc(
        'set_league_member_role',
        params: {
          'target_league': leagueId,
          'target_user': userId,
          'target_role': role,
        },
      );
    }
  }

  Future<void> removeLeagueMember(String leagueId, String userId) async {
    if (!isDemo) {
      await client!.rpc(
        'remove_league_member',
        params: {'target_league': leagueId, 'target_user': userId},
      );
    }
  }

  Future<void> transferLeagueOwnership(String leagueId, String userId) async {
    if (!isDemo) {
      await client!.rpc(
        'transfer_league_ownership',
        params: {'target_league': leagueId, 'target_user': userId},
      );
    }
  }

  Future<void> leaveLeague(String leagueId) async {
    if (!isDemo) {
      await client!.rpc('leave_league', params: {'target_league': leagueId});
    }
  }

  Future<String> rotateLeagueInvite(String leagueId) async => isDemo
      ? 'KICKLY8'
      : (await client!.rpc(
          'rotate_league_invite_code',
          params: {'target_league': leagueId},
        )).toString();

  Future<List<MatchSummary>> getMatches() async {
    if (isDemo) return demoMatches;
    final initial = await Future.wait<dynamic>([
      getLeagues(),
      getCurrentProfile(),
    ]);
    final leagues = initial[0] as List<LeagueSummary>;
    final profile = initial[1] as UserProfile?;
    final rows = await client!
        .from('matches')
        .select(
          'id, league_id, title, starts_at, location_name, city, province, '
          'latitude, longitude, cover_image_url, football_format, max_players, '
          'visibility, status, registration_closed_at',
        )
        .order('starts_at');
    final list = (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (list.isEmpty) return const [];
    final ids = list.map((e) => e['id'].toString()).toList();
    final leagueIds = list
        .map((e) => e['league_id'].toString())
        .toSet()
        .toList();
    final results = await Future.wait<dynamic>([
      client!
          .from('leagues')
          .select('id, name, slug, city')
          .inFilter('id', leagueIds),
      client!
          .from('match_participants')
          .select('match_id, user_id, response')
          .inFilter('match_id', ids),
      client!.rpc('get_visible_match_counts', params: {'target_matches': ids}),
    ]);
    final leagueRows = <String, JsonMap>{
      for (final raw in results[0] as List<dynamic>)
        (raw as Map)['id'].toString(): Map<String, dynamic>.from(raw),
    };
    final participantRows = (results[1] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final counts = <String, int>{
      for (final raw in results[2] as List<dynamic>? ?? const [])
        (raw as Map)['match_id'].toString(): asInt(raw['going_count']),
    };
    final ownLeagueIds = leagues.map((e) => e.id).toSet();
    final userId = currentUserId;
    final matches = list.map((row) {
      final league =
          leagueRows[row['league_id'].toString()] ?? const <String, dynamic>{};
      final response = participantRows
          .where(
            (p) =>
                p['match_id']?.toString() == row['id']?.toString() &&
                p['user_id']?.toString() == userId,
          )
          .map((p) => p['response']?.toString())
          .firstOrNull;
      final latitude = row['latitude'] == null
          ? null
          : asDouble(row['latitude']);
      final longitude = row['longitude'] == null
          ? null
          : asDouble(row['longitude']);
      return MatchSummary(
        id: row['id'].toString(),
        leagueId: row['league_id'].toString(),
        leagueName: league['name']?.toString() ?? 'Lega Kickly',
        leagueSlug: league['slug']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Partita',
        startsAt: asDate(row['starts_at']),
        locationName: row['location_name']?.toString() ?? '',
        city: row['city']?.toString() ?? league['city']?.toString() ?? '',
        footballFormat: row['football_format']?.toString() ?? '5v5',
        maxPlayers: asInt(row['max_players'], 10),
        goingCount: counts[row['id'].toString()] ?? 0,
        status: row['status']?.toString() ?? 'open',
        visibility: row['visibility']?.toString() ?? 'league_only',
        registrationClosedAt: row['registration_closed_at'] == null
            ? null
            : asDate(row['registration_closed_at']),
        currentResponse: response,
        isLeagueMember: ownLeagueIds.contains(row['league_id'].toString()),
        province: row['province']?.toString(),
        latitude: latitude,
        longitude: longitude,
        distanceKm:
            profile?.latitude == null ||
                profile?.longitude == null ||
                latitude == null ||
                longitude == null
            ? null
            : _distanceKm(
                profile!.latitude!,
                profile.longitude!,
                latitude,
                longitude,
              ),
        coverImageUrl: row['cover_image_url']?.toString(),
      );
    }).toList();
    matches.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return matches;
  }

  /// Partite pubbliche vicine con un posto ancora libero, per la sezione
  /// "cercano un decimo" in home. La distanza e il filtro "posti liberi"
  /// sono già calcolati lato server (vedi la RPC): qui c'è solo la mappatura
  /// verso MatchSummary, riusato così com'è dalla card e dalla schermata di
  /// dettaglio (che già sa gestire un non-membro su una partita pubblica).
  Future<List<MatchSummary>> getNearbyOpenSlotMatches() async {
    if (isDemo) return const [];
    final rows = await client!.rpc('get_nearby_open_slot_matches');
    return (rows as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return MatchSummary(
        id: row['match_id'].toString(),
        leagueId: row['league_id'].toString(),
        leagueName: row['league_name']?.toString() ?? 'Lega Kickly',
        leagueSlug: row['league_slug']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Partita',
        startsAt: asDate(row['starts_at']),
        locationName: row['location_name']?.toString() ?? '',
        city: row['city']?.toString() ?? '',
        province: row['province']?.toString(),
        footballFormat: row['football_format']?.toString() ?? '5v5',
        maxPlayers: asInt(row['max_players'], 10),
        goingCount: asInt(row['going_count']),
        status: row['status']?.toString() ?? 'open',
        visibility: 'public',
        registrationClosedAt: null,
        currentResponse: null,
        // Sempre false per costruzione: la RPC esclude esplicitamente le
        // leghe di cui il chiamante è già membro (altrimenti duplicherebbe
        // "In programma"), quindi ogni riga qui è per forza di una lega
        // esterna.
        isLeagueMember: false,
        distanceKm: row['distance_km'] == null
            ? null
            : asDouble(row['distance_km']),
        coverImageUrl: row['cover_image_url']?.toString(),
      );
    }).toList();
  }

  Future<List<MatchSummary>> getLeagueMatches(LeagueSummary league) async {
    if (isDemo) {
      return demoMatches.where((match) => match.leagueId == league.id).toList();
    }
    final data = await client!.rpc(
      'get_league_match_summaries',
      params: {'target_league': league.id},
    );
    return (data as List<dynamic>? ?? const [])
        .map(
          (row) => MatchSummary.fromRpc(
            Map<String, dynamic>.from(row as Map),
            league: league,
          ),
        )
        .toList();
  }

  Future<MatchDetail?> getMatch(String id) async {
    if (isDemo) {
      final summary = demoMatches.where((item) => item.id == id).firstOrNull;
      if (summary == null) return null;
      return MatchDetail(
        summary: summary,
        currentUserId: 'demo-user',
        createdBy: 'demo-user',
        description: 'Una partita Kickly aperta a tutti i membri della lega.',
        address: '${summary.locationName}, ${summary.city}',
        costTotal: 90,
        venuePhone: '+39 02 1234567',
        currentUserRole: 'admin',
        participants: List.generate(
          summary.goingCount,
          (index) => MatchParticipant(
            id: 'participant-$index',
            userId: index == 0 ? 'demo-user' : 'user-$index',
            username: index == 0 ? 'renato10' : 'player$index',
            firstName: index == 0 ? 'Renato' : 'Giocatore',
            lastName: index == 0 ? 'Bianchi' : '$index',
            avatarUrl: null,
            footballRole: [
              'goalkeeper',
              'defender',
              'midfielder',
              'forward',
            ][index % 4],
            overall: 70 + (index % 12),
            response: 'going',
            joinedAt: DateTime.now().subtract(Duration(hours: index)),
          ),
        ),
        lineupTeams: const [
          {
            'team_number': 1,
            'formation': '2-3-1',
            'captain_user_id': 'demo-user',
          },
          {'team_number': 2, 'formation': '2-3-1', 'captain_user_id': null},
        ],
        lineupPlayers: const [],
      );
    }

    final supabase = client!;
    final rawMatch = await supabase
        .from('matches')
        .select(
          'id, league_id, created_by, title, description, starts_at, '
          'location_name, address, city, football_format, max_players, '
          'cost_total, visibility, status, registration_closed_at, '
          'latitude, longitude, team_a_score, team_b_score, completed_at, '
          'mvp_voting_ends_at, mvp_finalized_at, province, cover_image_url, '
          'venue_image_url, venue_phone, field_booked_at, field_booked_by',
        )
        .eq('id', id)
        .maybeSingle();
    if (rawMatch == null) return null;
    final match = Map<String, dynamic>.from(rawMatch);
    final leagueId = match['league_id'].toString();
    final userId = currentUserId!;

    final results = await Future.wait<dynamic>([
      supabase
          .from('leagues')
          .select('id, name, slug, city, football_format')
          .eq('id', leagueId)
          .single(),
      supabase
          .from('league_members')
          .select('role')
          .eq('league_id', leagueId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle(),
      supabase
          .from('match_participants')
          .select('id, user_id, response, joined_at')
          .eq('match_id', id)
          .order('joined_at'),
      supabase
          .from('match_lineup_teams')
          .select('team_number, formation, captain_user_id')
          .eq('match_id', id)
          .order('team_number'),
      supabase
          .from('match_lineup_players')
          .select('user_id, team_number, slot_key')
          .eq('match_id', id),
    ]);
    final league = Map<String, dynamic>.from(results[0] as Map);
    final membership = results[1] == null
        ? null
        : Map<String, dynamic>.from(results[1] as Map);
    final participantRows = (results[2] as List<dynamic>? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final userIds = participantRows
        .map((row) => row['user_id'].toString())
        .toList();
    final profileRows = userIds.isEmpty
        ? <dynamic>[]
        : await supabase
              .from('profiles')
              .select(
                'id, first_name, last_name, username, avatar_path, primary_position, overall',
              )
              .inFilter('id', userIds);
    final profileMap = <String, JsonMap>{
      for (final raw in profileRows)
        (raw as Map)['id'].toString(): Map<String, dynamic>.from(raw),
    };
    final participants = participantRows.map((row) {
      final profile =
          profileMap[row['user_id'].toString()] ?? const <String, dynamic>{};
      final avatarPath = profile['avatar_path']?.toString();
      return MatchParticipant(
        id: row['id'].toString(),
        userId: row['user_id'].toString(),
        username: profile['username']?.toString() ?? 'giocatore',
        firstName: profile['first_name']?.toString(),
        lastName: profile['last_name']?.toString(),
        avatarUrl: _publicUrl('avatars', avatarPath),
        footballRole: profile['primary_position']?.toString(),
        overall: asInt(profile['overall'], 70),
        response: row['response']?.toString() ?? 'declined',
        joinedAt: asDate(row['joined_at']),
      );
    }).toList();
    final currentResponse = participantRows
        .where((row) => row['user_id'].toString() == userId)
        .map((row) => row['response']?.toString())
        .firstOrNull;
    final summary = MatchSummary(
      id: id,
      leagueId: leagueId,
      leagueName: league['name']?.toString() ?? 'Lega Kickly',
      leagueSlug: league['slug']?.toString() ?? '',
      title: match['title']?.toString() ?? 'Partita',
      startsAt: asDate(match['starts_at']),
      locationName: match['location_name']?.toString() ?? '',
      city: match['city']?.toString() ?? league['city']?.toString() ?? '',
      footballFormat: match['football_format']?.toString() ?? '5v5',
      maxPlayers: asInt(match['max_players'], 10),
      goingCount: participants.where((item) => item.response == 'going').length,
      status: match['status']?.toString() ?? 'open',
      visibility: match['visibility']?.toString() ?? 'league_only',
      registrationClosedAt: match['registration_closed_at'] == null
          ? null
          : asDate(match['registration_closed_at']),
      currentResponse: currentResponse,
      isLeagueMember: membership != null,
      province: match['province']?.toString(),
      latitude: match['latitude'] == null ? null : asDouble(match['latitude']),
      longitude: match['longitude'] == null
          ? null
          : asDouble(match['longitude']),
      coverImageUrl: match['cover_image_url']?.toString(),
    );
    final postGame =
        summary.status == 'completed' && match['completed_at'] != null
        ? await _loadPostGame(id, match, userId)
        : null;
    return MatchDetail(
      summary: summary,
      currentUserId: userId,
      createdBy: match['created_by'].toString(),
      description: match['description']?.toString(),
      address: match['address']?.toString(),
      costTotal: match['cost_total'] == null
          ? null
          : asDouble(match['cost_total']),
      currentUserRole: membership?['role']?.toString(),
      participants: participants,
      lineupTeams: (results[3] as List<dynamic>? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      lineupPlayers: (results[4] as List<dynamic>? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      latitude: match['latitude'] == null ? null : asDouble(match['latitude']),
      longitude: match['longitude'] == null
          ? null
          : asDouble(match['longitude']),
      postGame: postGame,
      coverImageUrl: match['cover_image_url']?.toString(),
      venueImageUrl: match['venue_image_url']?.toString(),
      venuePhone: match['venue_phone']?.toString(),
      fieldBookedAt: match['field_booked_at'] == null
          ? null
          : asDate(match['field_booked_at']),
      fieldBookedBy: match['field_booked_by']?.toString(),
    );
  }

  Future<void> setMatchResponse(String matchId, String response) async {
    if (isDemo) return;
    await client!.rpc(
      'set_match_response',
      params: {'target_match': matchId, 'target_response': response},
    );
  }

  Future<void> updateMatch({
    required String matchId,
    required String title,
    required String description,
    required DateTime startsAt,
    required String locationName,
    required String address,
    required String city,
    required String province,
    required double latitude,
    required double longitude,
    required String venuePhone,
    required String footballFormat,
    required int maxPlayers,
    required double? costTotal,
    required String visibility,
  }) async {
    if (isDemo) return;
    await client!.rpc(
      'update_match_details',
      params: {
        'target_match': matchId,
        'match_title': title.trim(),
        'match_description': description.trim(),
        'match_starts_at': startsAt.toUtc().toIso8601String(),
        'match_location_name': locationName.trim(),
        'match_address': address.trim(),
        'match_city': city.trim(),
        'match_province': province.trim(),
        'match_latitude': latitude,
        'match_longitude': longitude,
        'match_venue_phone': venuePhone.trim(),
        'match_football_format': footballFormat,
        'match_max_players': maxPlayers,
        'match_cost_total': costTotal,
        'match_visibility': visibility,
      },
    );
  }

  Future<void> setMatchAdminState(String matchId, String action) async {
    if (!isDemo) {
      await client!.rpc(
        'set_match_admin_state',
        params: {'target_match': matchId, 'target_action': action},
      );
    }
  }

  /// Conferma la prenotazione del campo e avvisa i partecipanti.
  ///
  /// Restituisce l'istante della prenotazione, che la RPC fornisce già come
  /// valore di ritorno. Prima veniva scartato e la card si affidava a un
  /// ricaricamento dell'intera pagina per accorgersi del cambiamento: la
  /// prenotazione finiva a buon fine sul database ma la schermata continuava a
  /// mostrare "Prenota il campo", come se non fosse successo niente.
  ///
  /// La RPC è idempotente: se il campo è già prenotato restituisce l'istante
  /// registrato in precedenza senza inviare una seconda notifica.
  Future<DateTime?> confirmFieldBooking(String matchId) async {
    if (isDemo) return DateTime.now();
    final data = await client!.rpc(
      'confirm_field_booking',
      params: {'target_match': matchId},
    );
    return data == null ? null : asDate(data);
  }

  Future<String> uploadMatchImage({
    required String matchId,
    required Uint8List bytes,
    required String extension,
    required String kind,
  }) async {
    if (isDemo) return '';
    final requested = extension.toLowerCase();
    final safeExtension = ['png', 'webp'].contains(requested)
        ? requested
        : 'jpg';
    final path = '$matchId/$kind.$safeExtension';
    await client!.storage
        .from('match-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: safeExtension == 'png'
                ? 'image/png'
                : safeExtension == 'webp'
                ? 'image/webp'
                : 'image/jpeg',
          ),
        );
    final publicUrl = client!.storage.from('match-media').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> setMatchMedia(
    String matchId, {
    String? coverImageUrl,
    String? venueImageUrl,
  }) async {
    if (!isDemo) {
      await client!.rpc(
        'set_match_media',
        params: {
          'target_match': matchId,
          'match_cover_image_url': coverImageUrl ?? '',
          'match_venue_image_url': venueImageUrl ?? '',
        },
      );
    }
  }

  /// Occupa uno slot del campo, spostandosi se il giocatore era già schierato.
  ///
  /// Con [captain] a true si candida anche come capitano della squadra, che è
  /// l'unico ruolo non-admin autorizzato a cambiare modulo.
  /// Restituisce lo stato aggiornato della formazione così che la pagina possa
  /// ridisegnare il campo senza ricaricare l'intera partita.
  Future<LineupSnapshot?> setLineupSlot(
    String matchId,
    int team,
    String slot, {
    bool captain = false,
  }) async {
    if (isDemo) return null;
    final data = await client!.rpc(
      'set_match_lineup_slot',
      params: {
        'target_match': matchId,
        'target_team': team,
        'target_slot': slot,
        'wants_captain': captain,
      },
    );
    return LineupSnapshot.fromRpc(data);
  }

  /// Libera la posizione del giocatore e, se lo era, gli toglie la fascia.
  Future<LineupSnapshot?> leaveLineup(String matchId) async {
    if (isDemo) return null;
    final data = await client!.rpc(
      'leave_match_lineup',
      params: {'target_match': matchId},
    );
    return LineupSnapshot.fromRpc(data);
  }

  /// Cambia il modulo di una squadra. La RPC accetta solo capitano della
  /// squadra oppure owner/admin della lega, e solo moduli validi per il formato.
  Future<LineupSnapshot?> setLineupFormation(
    String matchId,
    int team,
    String formation,
  ) async {
    if (isDemo) return null;
    final data = await client!.rpc(
      'set_match_lineup_formation',
      params: {
        'target_match': matchId,
        'target_team': team,
        'target_formation': formation,
      },
    );
    return LineupSnapshot.fromRpc(data);
  }

  /// Rilegge la formazione dal database.
  ///
  /// Usato quando arriva un evento Realtime: l'evento dice che qualcosa è
  /// cambiato ma non porta con sé lo stato completo delle due tabelle.
  Future<LineupSnapshot?> getLineup(String matchId) async {
    if (isDemo) return null;
    final results = await Future.wait<dynamic>([
      client!
          .from('match_lineup_teams')
          .select('team_number, formation, captain_user_id')
          .eq('match_id', matchId)
          .order('team_number'),
      client!
          .from('match_lineup_players')
          .select('user_id, team_number, slot_key')
          .eq('match_id', matchId),
    ]);
    return LineupSnapshot(
      teams: LineupSnapshot.rowsOf(results[0]),
      players: LineupSnapshot.rowsOf(results[1]),
    );
  }

  Future<int> sendMatchReminder(String matchId, String body) async {
    if (isDemo) return 8;
    final data = await client!.rpc(
      'send_match_reminder',
      params: {'target_match': matchId, 'reminder_body': body.trim()},
    );
    return data is Map ? asInt(data['recipient_count']) : 0;
  }

  Future<void> finalizeMatch(
    String matchId, {
    required List<String> teamA,
    required List<String> teamB,
    required int scoreA,
    required int scoreB,
    required List<JsonMap> playerTotals,
  }) async {
    if (!isDemo) {
      await client!.rpc(
        'finalize_match',
        params: {
          'target_match': matchId,
          'team_a_players': teamA,
          'team_b_players': teamB,
          'score_a': scoreA,
          'score_b': scoreB,
          'player_totals': playerTotals,
        },
      );
    }
  }

  Future<void> castMvpVote(String matchId, String playerId) async {
    if (!isDemo) {
      await client!.rpc(
        'cast_mvp_vote',
        params: {'target_match': matchId, 'target_player': playerId},
      );
    }
  }

  Future<void> finalizeMvp(String matchId) async {
    if (!isDemo) {
      await client!.rpc(
        'finalize_match_mvp',
        params: {'target_match': matchId},
      );
    }
  }

  Future<String> createMatch({
    required String leagueId,
    required String title,
    required String description,
    required DateTime startsAt,
    required String locationName,
    required String address,
    required String city,
    required String province,
    required double latitude,
    required double longitude,
    required String venuePhone,
    required String footballFormat,
    required int maxPlayers,
    required double? costTotal,
    required String visibility,
  }) async {
    if (isDemo) return demoMatches.first.id;
    final result = await client!.rpc(
      'create_match',
      params: {
        'target_league': leagueId,
        'match_title': title.trim(),
        'match_description': description.trim(),
        'match_starts_at': startsAt.toUtc().toIso8601String(),
        'match_location_name': locationName.trim(),
        'match_address': address.trim(),
        'match_city': city.trim(),
        'match_province': province.trim(),
        'match_latitude': latitude,
        'match_longitude': longitude,
        'match_venue_phone': venuePhone.trim(),
        'match_football_format': footballFormat,
        'match_max_players': maxPlayers,
        'match_cost_total': costTotal,
        'match_visibility': visibility,
      },
    );
    return result.toString();
  }

  Future<DashboardData> getDashboard() async {
    final profile = await getCurrentProfile() ?? demoProfile;
    if (isDemo) {
      return DashboardData(
        profile: profile,
        stats: const PlayerStats(
          matches: 24,
          wins: 15,
          draws: 3,
          losses: 6,
          goals: 11,
          assists: 8,
          mvp: 4,
          overall: 78,
        ),
        unreadNotifications: demoNotifications
            .where((item) => item.readAt == null)
            .length,
        nextMatch: demoMatches.first,
        leagues: demoLeagues,
      );
    }
    final userId = currentUserId!;
    final results = await Future.wait<dynamic>([
      client!
          .from('player_stats')
          .select(
            'matches_played, wins, draws, losses, goals, assists, mvp_awards, overall',
          )
          .eq('user_id', userId)
          .isFilter('league_id', null)
          .isFilter('season_id', null)
          .maybeSingle(),
      getLeagues(),
      getNotifications(),
      client!
          .from('player_match_stats')
          .select(
            'match_id, goals, assists, match_rating, result, is_mvp, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle(),
    ]);
    final statsMap = results[0] == null
        ? null
        : Map<String, dynamic>.from(results[0] as Map);
    final leagues = results[1] as List<LeagueSummary>;
    final notifications = results[2] as List<KicklyNotification>;
    final lastStats = results[3] == null
        ? null
        : Map<String, dynamic>.from(results[3] as Map);
    final matchGroups = await Future.wait(leagues.map(getLeagueMatches));
    final matches =
        matchGroups
            .expand((group) => group)
            .where((match) => !match.isPast)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    // Sezione supplementare, non essenziale: se la RPC fallisce (rete,
    // profilo senza posizione impostata) la home deve comunque caricare
    // tutto il resto. Un errore qui non è mai motivo per mostrare la
    // schermata di errore dell'intera dashboard.
    final openNearby = await getNearbyOpenSlotMatches().catchError(
      (_) => const <MatchSummary>[],
    );
    LastMatchSummary? lastMatch;
    if (lastStats != null) {
      final row = await client!
          .from('matches')
          .select('id, league_id, title, team_a_score, team_b_score')
          .eq('id', lastStats['match_id'])
          .maybeSingle();
      if (row != null) {
        final match = Map<String, dynamic>.from(row);
        lastMatch = LastMatchSummary(
          id: match['id'].toString(),
          title: match['title']?.toString() ?? 'Partita',
          leagueName:
              leagues
                  .where((l) => l.id == match['league_id']?.toString())
                  .map((l) => l.name)
                  .firstOrNull ??
              'Lega Kickly',
          teamAScore: asInt(match['team_a_score']),
          teamBScore: asInt(match['team_b_score']),
          goals: asInt(lastStats['goals']),
          assists: asInt(lastStats['assists']),
          rating: lastStats['match_rating'] == null
              ? null
              : asDouble(lastStats['match_rating']),
          result: lastStats['result']?.toString() ?? 'draw',
          isMvp: lastStats['is_mvp'] == true,
        );
      }
    }
    return DashboardData(
      profile: profile,
      stats: PlayerStats.fromMap(statsMap, fallbackOverall: profile.overall),
      unreadNotifications: notifications
          .where((item) => item.readAt == null)
          .length,
      nextMatch: matches.firstOrNull,
      leagues: leagues.take(4).toList(),
      lastMatch: lastMatch,
      nearby: matches.skip(1).take(4).toList(),
      openNearby: openNearby,
    );
  }

  Future<List<KicklyNotification>> getNotifications() async {
    if (isDemo) return demoNotifications;
    final userId = currentUserId;
    if (userId == null) return const [];
    final rows = await client!
        .from('notifications')
        .select('id, type, title, body, link, read_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(80);
    return (rows as List<dynamic>)
        .map(
          (row) =>
              KicklyNotification.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> markNotificationRead(String id) async {
    if (isDemo) return;
    await client!
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  Future<void> markAllNotificationsRead() async {
    if (isDemo) return;
    await client!
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', currentUserId!)
        .isFilter('read_at', null);
  }

  Future<JsonMap> getNotificationPreferences() async {
    const defaults = <String, dynamic>{
      'match_created': true,
      'match_updates': true,
      'match_reminders': true,
      'waitlist': true,
      'mvp': true,
      'rating': true,
      'league_updates': true,
      'push_enabled': true,
    };
    if (isDemo) return {...defaults};
    final row = await client!
        .from('notification_preferences')
        .select(
          'match_created, match_updates, match_reminders, waitlist, mvp, rating, league_updates, push_enabled',
        )
        .eq('user_id', currentUserId!)
        .maybeSingle();
    return {...defaults, if (row != null) ...Map<String, dynamic>.from(row)};
  }

  Future<void> updateNotificationPreferences(JsonMap preferences) async {
    if (isDemo) return;
    await client!.from('notification_preferences').upsert({
      'user_id': currentUserId,
      ...preferences,
    }, onConflict: 'user_id');
  }

  Future<ProfileDetails> getProfileDetails() async {
    final profile = await getCurrentProfile() ?? demoProfile;
    if (isDemo) {
      return ProfileDetails(
        profile: profile,
        stats: const PlayerStats(
          matches: 24,
          wins: 15,
          draws: 3,
          losses: 6,
          goals: 11,
          assists: 8,
          mvp: 4,
          overall: 78,
        ),
        history: List.generate(
          8,
          (index) => {'new_rating': 72 + index, 'delta': index.isEven ? 1 : 0},
        ),
        form: const ['win', 'win', 'loss', 'draw', 'win'],
      );
    }
    final userId = profile.id;
    final results = await Future.wait<dynamic>([
      client!
          .from('player_stats')
          .select(
            'matches_played, wins, draws, losses, goals, assists, mvp_awards, overall',
          )
          .eq('user_id', userId)
          .isFilter('league_id', null)
          .isFilter('season_id', null)
          .maybeSingle(),
      client!
          .from('player_rating_history')
          .select('id, previous_rating, new_rating, delta, created_at')
          .eq('user_id', userId)
          .not('match_id', 'is', null)
          .order('created_at')
          .limit(10),
      client!
          .from('player_match_stats')
          .select('result, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5),
    ]);
    return ProfileDetails(
      profile: profile,
      stats: PlayerStats.fromMap(
        results[0] == null
            ? null
            : Map<String, dynamic>.from(results[0] as Map),
        fallbackOverall: profile.overall,
      ),
      history: (results[1] as List<dynamic>? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      form: (results[2] as List<dynamic>? ?? const [])
          .map((row) => (row as Map)['result'].toString())
          .toList(),
    );
  }

  Future<ProfileDetails?> getPublicProfile(String username) async {
    if (isDemo) return getProfileDetails();
    final row = await client!
        .from('profiles')
        .select(
          'id, username, first_name, last_name, avatar_path, primary_position, secondary_position, preferred_foot, skill_level, birth_date, city, profile_public, overall, timezone, onboarding_completed',
        )
        .eq('username', username)
        .eq('profile_public', true)
        .maybeSingle();
    if (row == null) return null;
    final profile = _mapProfile(Map<String, dynamic>.from(row));
    final results = await Future.wait<dynamic>([
      client!
          .from('player_stats')
          .select(
            'matches_played, wins, draws, losses, goals, assists, mvp_awards, overall',
          )
          .eq('user_id', profile.id)
          .isFilter('league_id', null)
          .isFilter('season_id', null)
          .maybeSingle(),
      client!
          .from('player_rating_history')
          .select('id, previous_rating, new_rating, delta, created_at')
          .eq('user_id', profile.id)
          .not('match_id', 'is', null)
          .order('created_at')
          .limit(10),
      client!
          .from('player_match_stats')
          .select('result, created_at')
          .eq('user_id', profile.id)
          .order('created_at', ascending: false)
          .limit(5),
    ]);
    return ProfileDetails(
      profile: profile,
      stats: PlayerStats.fromMap(
        results[0] == null
            ? null
            : Map<String, dynamic>.from(results[0] as Map),
        fallbackOverall: profile.overall,
      ),
      history: (results[1] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      form: (results[2] as List<dynamic>? ?? const [])
          .map((e) => (e as Map)['result'].toString())
          .toList(),
    );
  }

  /// Segnala un utente a chi amministra il progetto.
  ///
  /// Nessuna coda di moderazione in-app (vedi "Non-obiettivi" della spec di
  /// sicurezza): la riga finisce in `user_reports`, leggibile solo da SQL/
  /// dashboard Supabase (nessuna policy SELECT per `authenticated`), quindi
  /// un insert riuscito senza eccezioni e' l'unica conferma che serve alla UI.
  Future<void> reportUser({
    required String reportedUserId,
    String? leagueId,
    required String reason,
    String? details,
  }) async {
    if (isDemo) return;
    final trimmedDetails = details?.trim();
    await client!.from('user_reports').insert({
      'reporter_id': currentUserId,
      'reported_user_id': reportedUserId,
      'league_id': leagueId,
      'reason': reason,
      'details': trimmedDetails == null || trimmedDetails.isEmpty
          ? null
          : trimmedDetails,
    });
  }

  /// Blocca un utente: da questo momento nessuno dei due vede piu' il
  /// profilo dell'altro nella lega condivisa (filtro lato RLS, vedi
  /// `private.is_blocked_pair` in
  /// 20260821090100_block_visibility_filter.sql), e sparisce dalle liste
  /// membri/classifica di entrambi (20260821090200_league_lists_hide_blocked_users.sql).
  ///
  /// `upsert` con `ignoreDuplicates` invece di `insert` semplice: bloccare
  /// due volte lo stesso utente (doppio tap, retry di rete) non deve far
  /// fallire la seconda chiamata con una violazione di chiave primaria — il
  /// risultato desiderato ("e' bloccato") e' gia' vero, quindi va trattato
  /// come successo silenzioso, non come errore da mostrare all'utente.
  Future<void> blockUser(String blockedUserId) async {
    if (isDemo) return;
    await client!
        .from('user_blocks')
        .upsert(
          {'blocker_id': currentUserId, 'blocked_id': blockedUserId},
          onConflict: 'blocker_id,blocked_id',
          ignoreDuplicates: true,
        );
  }

  Future<MatchPostGame> _loadPostGame(
    String matchId,
    JsonMap match,
    String userId,
  ) async {
    final results = await Future.wait<dynamic>([
      client!
          .from('match_teams')
          .select('id, name, team_number')
          .eq('match_id', matchId)
          .order('team_number'),
      client!
          .from('match_team_players')
          .select('team_id, user_id')
          .eq('match_id', matchId),
      client!
          .from('player_match_stats')
          .select(
            'user_id, team_id, goals, assists, result, is_mvp, match_rating, previous_overall, new_overall, rating_delta',
          )
          .eq('match_id', matchId),
      client!
          .from('mvp_votes')
          .select('voted_player_id')
          .eq('match_id', matchId)
          .eq('voter_id', userId)
          .maybeSingle(),
    ]);
    final assignments = (results[1] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final teams = (results[0] as List<dynamic>? ?? const []).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return <String, dynamic>{
        ...row,
        'player_ids': assignments
            .where((a) => a['team_id'] == row['id'])
            .map((a) => a['user_id'].toString())
            .toList(),
      };
    }).toList();
    return MatchPostGame(
      teamAScore: asInt(match['team_a_score']),
      teamBScore: asInt(match['team_b_score']),
      completedAt: asDate(match['completed_at']),
      mvpVotingEndsAt: asDate(
        match['mvp_voting_ends_at'] ?? match['completed_at'],
      ),
      mvpFinalizedAt: match['mvp_finalized_at'] == null
          ? null
          : asDate(match['mvp_finalized_at']),
      teams: teams,
      playerStats: (results[2] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      ownVotePlayerId: results[3] == null
          ? null
          : (results[3] as Map)['voted_player_id']?.toString(),
    );
  }

  UserProfile _mapProfile(JsonMap row) {
    final avatarPath = row['avatar_path']?.toString();
    return UserProfile.fromMap(
      row,
      avatarUrl: _publicUrl('avatars', avatarPath),
    );
  }

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty || client == null) return null;
    return client!.storage.from(bucket).getPublicUrl(path);
  }
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final deltaLatitude = _radians(lat2 - lat1);
  final deltaLongitude = _radians(lon2 - lon1);
  final a =
      math.sin(deltaLatitude / 2) * math.sin(deltaLatitude / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(deltaLongitude / 2) *
          math.sin(deltaLongitude / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;

const _introSeenPrefsKey = 'kickly.onboarding.introSeen';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({required this.repository});

  final KicklyRepository repository;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _notificationChannel;
  bool _initializing = true;
  bool _demoSession = false;
  bool _onboardingComplete = false;
  // Non ha niente a che fare con `_onboardingComplete` (quella è il form
  // "che giocatore sei?" post-signup): questo flag è solo "il dispositivo ha
  // già visto la vetrina a episodi pre-login almeno una volta", per non
  // rimostrarla a ogni riavvio dell'app finché resta disinstallata.
  bool _introSeen = false;
  KicklyNotification? latestNotification;
  int notificationRevision = 0;

  /// L'app è visibile in questo momento?
  ///
  /// Decide come consegnare una notifica in arrivo: con l'app aperta basta la
  /// SnackBar in-app, che non interrompe; con l'app in background serve il
  /// banner di sistema, altrimenti l'avviso non esiste per l'utente.
  bool _foreground = true;

  bool get initializing => _initializing;
  bool get isSignedIn =>
      repository.isDemo ? _demoSession : repository.currentUserId != null;
  bool get onboardingComplete => _onboardingComplete;
  bool get introSeen => _introSeen;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    // Letto prima di refreshSession: il primo redirect del router (in
    // app.dart) decide già "vetrina o login" in base a questo valore, quindi
    // dev'essere pronto prima che _initializing torni false.
    final prefs = await SharedPreferences.getInstance();
    _introSeen = prefs.getBool(_introSeenPrefsKey) ?? false;
    if (!repository.isDemo) {
      _authSubscription = repository.authStateChanges?.listen(
        (_) => refreshSession(),
      );
    }
    await refreshSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  Future<void> refreshSession() async {
    _initializing = true;
    notifyListeners();
    if (isSignedIn) {
      try {
        _onboardingComplete =
            (await repository.getCurrentProfile())?.onboardingCompleted ??
            false;
      } catch (_) {
        _onboardingComplete = false;
      }
      _listenForNotifications();
      // Il permesso viene chiesto a sessione aperta, non al primo avvio: sulla
      // schermata di login il motivo non è chiaro e si finisce col negarlo.
      unawaited(_enableSystemNotifications());
    } else {
      _onboardingComplete = false;
      final channel = _notificationChannel;
      // Fire-and-forget voluto: chiudere il canale realtime parla con il socket
      // e al logout la rete può già essere caduta. Aspettarla bloccherebbe il
      // ritorno alla schermata di login dietro un timeout; il riferimento
      // locale + `_notificationChannel = null` qui sotto garantiscono comunque
      // che nessuno riusi il canale mentre si smonta.
      if (channel != null) unawaited(channel.unsubscribe());
      _notificationChannel = null;
      unawaited(stopNotificationPolling());
    }
    _initializing = false;
    notifyListeners();
  }

  /// Chiede il permesso notifiche e accende il controllo periodico che copre il
  /// caso "app chiusa".
  Future<void> _enableSystemNotifications() async {
    if (repository.isDemo) return;
    try {
      await NotificationService.instance.requestPermission();
      await startNotificationPolling();
    } catch (error) {
      // Un permesso negato o un task non registrabile non deve impedire l'uso
      // dell'app: restano le notifiche in-app.
      debugPrint('Notifiche di sistema non attivate: $error');
    }
  }

  Future<void> startDemo() async {
    _demoSession = true;
    _onboardingComplete = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    notifyListeners();
  }

  /// Chiamato sia dal tap "Comincia" sull'ultimo passo della vetrina, sia
  /// dalla X per saltarla: in entrambi i casi il dispositivo non deve
  /// rivederla al prossimo avvio, quindi il flag va scritto su disco subito,
  /// non solo tenuto in memoria.
  Future<void> completeIntro() async {
    _introSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenPrefsKey, true);
    notifyListeners();
  }

  Future<void> signOut() async {
    if (repository.isDemo) {
      _demoSession = false;
      _onboardingComplete = false;
    } else {
      await repository.signOut();
    }
    notifyListeners();
  }

  void _listenForNotifications() {
    if (repository.isDemo ||
        _notificationChannel != null ||
        repository.currentUserId == null) {
      return;
    }
    _notificationChannel = repository.client!
        .channel('kickly-mobile-runtime-${repository.currentUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: repository.currentUserId!,
          ),
          callback: (payload) {
            final notification = KicklyNotification.fromMap(payload.newRecord);
            latestNotification = notification;
            notificationRevision += 1;
            notifyListeners();

            // Con l'app aperta la SnackBar in-app basta e non interrompe; con
            // l'app in background l'unico modo per farla arrivare è il banner
            // di sistema.
            if (!_foreground) {
              unawaited(NotificationService.instance.show(notification));
            }
            // In entrambi i casi la notifica è stata gestita: spostiamo il
            // cursore così il controllo periodico non la ripubblica.
            unawaited(markNotificationsSeen(notification.createdAt));
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _notificationChannel?.unsubscribe();
    super.dispose();
  }
}
