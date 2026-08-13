import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
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

  Future<void> signOut() async => client?.auth.signOut();

  Future<UserProfile?> getCurrentProfile() async {
    if (isDemo) return demoProfile;
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await client!
        .from('profiles')
        .select(
          'id, username, first_name, last_name, avatar_path, primary_position, '
          'skill_level, overall, timezone, onboarding_completed',
        )
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _mapProfile(Map<String, dynamic>.from(row));
  }

  Future<void> saveProfile({
    required String username,
    required String firstName,
    required String lastName,
    required String primaryPosition,
    required String skillLevel,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) async {
    if (isDemo) return;
    final userId = currentUserId;
    if (userId == null) throw StateError('Sessione non disponibile.');

    String? avatarPath;
    if (avatarBytes != null) {
      final extension = avatarExtension?.toLowerCase() == 'png' ? 'png' : 'jpg';
      avatarPath = '$userId/avatar.$extension';
      await client!.storage
          .from('avatars')
          .uploadBinary(
            avatarPath,
            avatarBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
    }

    final payload = <String, dynamic>{
      'id': userId,
      'username': username.trim().toLowerCase(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'primary_position': primaryPosition,
      'skill_level': skillLevel,
      'onboarding_completed': true,
    };
    if (avatarPath != null) payload['avatar_path'] = avatarPath;
    await client!.from('profiles').upsert(payload, onConflict: 'id');
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
      },
    );
    final rows = data as List<dynamic>? ?? const [];
    if (rows.isEmpty) throw StateError('Lega non creata.');
    return (rows.first as Map)['slug'].toString();
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

  Future<List<MatchSummary>> getMatches() async {
    if (isDemo) return demoMatches;
    final leagues = await getLeagues();
    final groups = await Future.wait(leagues.map(getLeagueMatches));
    final seen = <String>{};
    final matches = groups
        .expand((group) => group)
        .where((item) => seen.add(item.id))
        .toList();
    matches.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return matches;
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
          'cost_total, visibility, status, registration_closed_at',
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
    );
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
    );
  }

  Future<void> setMatchResponse(String matchId, String response) async {
    if (isDemo) return;
    await client!.rpc(
      'set_match_response',
      params: {'target_match': matchId, 'target_response': response},
    );
  }

  Future<String> createMatch({
    required String leagueId,
    required String title,
    required String description,
    required DateTime startsAt,
    required String locationName,
    required String address,
    required String city,
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
    ]);
    final statsMap = results[0] == null
        ? null
        : Map<String, dynamic>.from(results[0] as Map);
    final leagues = results[1] as List<LeagueSummary>;
    final notifications = results[2] as List<KicklyNotification>;
    final matchGroups = await Future.wait(leagues.map(getLeagueMatches));
    final matches =
        matchGroups
            .expand((group) => group)
            .where((match) => !match.isPast)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return DashboardData(
      profile: profile,
      stats: PlayerStats.fromMap(statsMap, fallbackOverall: profile.overall),
      unreadNotifications: notifications
          .where((item) => item.readAt == null)
          .length,
      nextMatch: matches.firstOrNull,
      leagues: leagues.take(4).toList(),
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

class AppState extends ChangeNotifier {
  AppState({required this.repository});

  final KicklyRepository repository;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initializing = true;
  bool _demoSession = false;
  bool _onboardingComplete = false;

  bool get initializing => _initializing;
  bool get isSignedIn =>
      repository.isDemo ? _demoSession : repository.currentUserId != null;
  bool get onboardingComplete => _onboardingComplete;

  Future<void> initialize() async {
    if (!repository.isDemo) {
      _authSubscription = repository.authStateChanges?.listen(
        (_) => refreshSession(),
      );
    }
    await refreshSession();
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
    } else {
      _onboardingComplete = false;
    }
    _initializing = false;
    notifyListeners();
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

  Future<void> signOut() async {
    if (repository.isDemo) {
      _demoSession = false;
      _onboardingComplete = false;
    } else {
      await repository.signOut();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
