import 'dart:convert';

typedef JsonMap = Map<String, dynamic>;

String repairText(String value) {
  var candidate = value;
  for (var pass = 0; pass < 3; pass++) {
    if (!RegExp(r'[ÃÂâð]').hasMatch(candidate)) break;
    try {
      final decoded = utf8.decode(latin1.encode(candidate));
      if (decoded == candidate) break;
      candidate = decoded;
    } catch (_) {
      break;
    }
  }
  return candidate;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime asDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.primaryPosition,
    required this.skillLevel,
    this.birthDate,
    this.city,
    this.province,
    this.latitude,
    this.longitude,
    this.secondaryPosition,
    this.preferredFoot,
    this.profilePublic = true,
    required this.overall,
    required this.timezone,
    required this.onboardingCompleted,
  });

  factory UserProfile.fromMap(JsonMap map, {String? avatarUrl}) => UserProfile(
    id: map['id']?.toString() ?? '',
    username: map['username']?.toString() ?? 'giocatore',
    firstName: map['first_name']?.toString(),
    lastName: map['last_name']?.toString(),
    avatarUrl: avatarUrl,
    primaryPosition: map['primary_position']?.toString(),
    skillLevel: map['skill_level']?.toString(),
    birthDate: map['birth_date']?.toString(),
    city: map['city']?.toString(),
    province: map['province']?.toString(),
    latitude: map['latitude'] == null ? null : asDouble(map['latitude']),
    longitude: map['longitude'] == null ? null : asDouble(map['longitude']),
    secondaryPosition: map['secondary_position']?.toString(),
    preferredFoot: map['preferred_foot']?.toString(),
    profilePublic: map['profile_public'] != false,
    overall: asInt(map['overall'], 70),
    timezone: map['timezone']?.toString() ?? 'Europe/Rome',
    onboardingCompleted: map['onboarding_completed'] == true,
  );

  final String id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? primaryPosition;
  final String? skillLevel;
  final String? birthDate;
  final String? city;
  final String? province;
  final double? latitude;
  final double? longitude;
  final String? secondaryPosition;
  final String? preferredFoot;
  final bool profilePublic;
  final int overall;
  final String timezone;
  final bool onboardingCompleted;

  String get displayName {
    final value = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return value.isEmpty ? '@$username' : value;
  }
}

class PlayerStats {
  const PlayerStats({
    this.matches = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goals = 0,
    this.assists = 0,
    this.mvp = 0,
    this.overall = 70,
  });

  factory PlayerStats.fromMap(JsonMap? map, {int fallbackOverall = 70}) =>
      PlayerStats(
        matches: asInt(map?['matches_played']),
        wins: asInt(map?['wins']),
        draws: asInt(map?['draws']),
        losses: asInt(map?['losses']),
        goals: asInt(map?['goals']),
        assists: asInt(map?['assists']),
        mvp: asInt(map?['mvp_awards']),
        overall: asInt(map?['overall'], fallbackOverall),
      );

  final int matches;
  final int wins;
  final int draws;
  final int losses;
  final int goals;
  final int assists;
  final int mvp;
  final int overall;

  int get winRate => matches == 0 ? 0 : ((wins / matches) * 100).round();
}

class LeagueSummary {
  const LeagueSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.logoUrl,
    required this.city,
    required this.country,
    required this.visibility,
    required this.footballFormat,
    required this.maxMembers,
    required this.memberCount,
    required this.currentUserRole,
  });

  factory LeagueSummary.fromRpc(JsonMap map) => LeagueSummary(
    id: map['id'].toString(),
    name: map['name']?.toString() ?? 'Lega Kickly',
    slug: map['slug']?.toString() ?? '',
    description: map['description']?.toString(),
    logoUrl: map['logo_url']?.toString(),
    city: map['city']?.toString() ?? '',
    country: map['country']?.toString() ?? 'Italia',
    visibility: map['visibility']?.toString() ?? 'private',
    footballFormat: map['football_format']?.toString() ?? '5v5',
    maxMembers: asInt(map['max_members'], 20),
    memberCount: asInt(map['member_count']),
    currentUserRole: map['current_user_role']?.toString() ?? 'member',
  );

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? logoUrl;
  final String city;
  final String country;
  final String visibility;
  final String footballFormat;
  final int maxMembers;
  final int memberCount;
  final String currentUserRole;

  bool get canManage =>
      currentUserRole == 'owner' || currentUserRole == 'admin';

  /// Conteggio membri già declinato: "1 membro" invece di "1 membri".
  String get memberCountLabel =>
      '$memberCount ${memberCount == 1 ? 'membro' : 'membri'}';

  /// Ruolo in italiano, con l'iniziale maiuscola.
  ///
  /// Prima veniva mostrato il valore grezzo del database ('owner', 'admin'),
  /// che stonava in mezzo a un'interfaccia tutta in italiano.
  String get roleLabel => leagueRoleLabel(currentUserRole);
}

/// Traduzione dei ruoli di lega, condivisa fra le schermate.
String leagueRoleLabel(String role) => switch (role) {
  'owner' => 'Proprietario',
  'admin' => 'Admin',
  'member' => 'Membro',
  _ => role,
};

class LeagueMember {
  const LeagueMember({
    required this.id,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.footballRole,
    required this.leagueRole,
    required this.joinedAt,
  });

  final String id;
  final String userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? footballRole;
  final String leagueRole;
  final DateTime joinedAt;

  String get displayName {
    final name = [firstName, lastName].whereType<String>().join(' ').trim();
    return name.isEmpty ? '@$username' : name;
  }
}

class LeagueDetail {
  const LeagueDetail({
    required this.summary,
    required this.ownerId,
    required this.inviteCode,
    required this.members,
  });

  final LeagueSummary summary;
  final String ownerId;
  final String inviteCode;
  final List<LeagueMember> members;
}

class LeagueCommunication {
  const LeagueCommunication({
    required this.id,
    required this.matchId,
    required this.createdBy,
    required this.kind,
    required this.title,
    required this.body,
    required this.pinned,
    required this.createdAt,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatarUrl,
  });
  final String id;
  final String? matchId;
  final String createdBy;
  final String kind;
  final String title;
  final String body;
  final bool pinned;
  final DateTime createdAt;
  final String authorName;
  final String authorUsername;
  final String? authorAvatarUrl;
}

class LeaderboardPlayer {
  const LeaderboardPlayer({
    required this.userId,
    required this.username,
    required this.name,
    this.avatarUrl,
    required this.matches,
    required this.goals,
    required this.assists,
    required this.mvp,
    required this.overall,
  });
  final String userId;
  final String username;
  final String name;
  final String? avatarUrl;
  final int matches;
  final int goals;
  final int assists;
  final int mvp;
  final int overall;
}

class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.leagueId,
    required this.leagueName,
    required this.leagueSlug,
    required this.title,
    required this.startsAt,
    required this.locationName,
    required this.city,
    required this.footballFormat,
    required this.maxPlayers,
    required this.goingCount,
    required this.status,
    required this.visibility,
    required this.registrationClosedAt,
    required this.currentResponse,
    required this.isLeagueMember,
    this.province,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.coverImageUrl,
  });

  factory MatchSummary.fromRpc(JsonMap map, {required LeagueSummary league}) =>
      MatchSummary(
        id: map['id'].toString(),
        leagueId: map['league_id'].toString(),
        leagueName: league.name,
        leagueSlug: league.slug,
        title: map['title']?.toString() ?? 'Partita',
        startsAt: asDate(map['starts_at']),
        locationName: map['location_name']?.toString() ?? '',
        city: map['city']?.toString() ?? league.city,
        footballFormat:
            map['football_format']?.toString() ?? league.footballFormat,
        maxPlayers: asInt(map['max_players'], 10),
        goingCount: asInt(map['going_count']),
        status: map['status']?.toString() ?? 'open',
        visibility: map['visibility']?.toString() ?? 'league_only',
        registrationClosedAt: map['registration_closed_at'] == null
            ? null
            : asDate(map['registration_closed_at']),
        currentResponse: map['current_response']?.toString(),
        isLeagueMember: true,
        province: map['province']?.toString(),
        latitude: map['latitude'] == null ? null : asDouble(map['latitude']),
        longitude: map['longitude'] == null ? null : asDouble(map['longitude']),
        coverImageUrl: map['cover_image_url']?.toString(),
      );

  final String id;
  final String leagueId;
  final String leagueName;
  final String leagueSlug;
  final String title;
  final DateTime startsAt;
  final String locationName;
  final String city;
  final String footballFormat;
  final int maxPlayers;
  final int goingCount;
  final String status;
  final String visibility;
  final DateTime? registrationClosedAt;
  final String? currentResponse;
  final bool isLeagueMember;
  final String? province;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? coverImageUrl;

  bool get isPast => startsAt.isBefore(DateTime.now()) || status == 'completed';
}

class MatchParticipant {
  const MatchParticipant({
    required this.id,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.footballRole,
    required this.overall,
    required this.response,
    required this.joinedAt,
  });

  final String id;
  final String userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? footballRole;
  final int overall;
  final String response;
  final DateTime joinedAt;

  String get displayName {
    final name = [firstName, lastName].whereType<String>().join(' ').trim();
    return name.isEmpty ? '@$username' : name;
  }
}

class MatchDetail {
  const MatchDetail({
    required this.summary,
    required this.currentUserId,
    required this.createdBy,
    required this.description,
    required this.address,
    required this.costTotal,
    required this.currentUserRole,
    required this.participants,
    required this.lineupTeams,
    required this.lineupPlayers,
    this.latitude,
    this.longitude,
    this.postGame,
    this.coverImageUrl,
    this.venueImageUrl,
    this.venuePhone,
    this.fieldBookedAt,
    this.fieldBookedBy,
  });

  final MatchSummary summary;
  final String currentUserId;
  final String createdBy;
  final String? description;
  final String? address;
  final double? costTotal;
  final String? currentUserRole;
  final List<MatchParticipant> participants;
  final List<JsonMap> lineupTeams;
  final List<JsonMap> lineupPlayers;
  final double? latitude;
  final double? longitude;
  final MatchPostGame? postGame;
  final String? coverImageUrl;
  final String? venueImageUrl;
  final String? venuePhone;
  final DateTime? fieldBookedAt;
  final String? fieldBookedBy;

  bool get canManage =>
      currentUserRole == 'owner' || currentUserRole == 'admin';
}

/// Stato completo della formazione di una partita: le due squadre con modulo e
/// capitano, e l'elenco di chi occupa quale slot.
///
/// È esattamente il jsonb che le RPC `set_match_lineup_slot`,
/// `leave_match_lineup` e `set_match_lineup_formation` restituiscono già oggi
/// (via `private.match_lineup_snapshot`). Prima veniva scartato e la pagina
/// rifaceva una `getMatch()` da sei query per ricostruire lo stesso dato: usare
/// lo snapshot rende la scelta della posizione immediata invece di far
/// aspettare un round-trip completo.
class LineupSnapshot {
  const LineupSnapshot({required this.teams, required this.players});

  /// Righe di `match_lineup_teams`: team_number, formation, captain_user_id.
  final List<JsonMap> teams;

  /// Righe di `match_lineup_players`: user_id, team_number, slot_key.
  final List<JsonMap> players;

  /// Legge lo snapshot restituito da una RPC; tollera un payload vuoto o
  /// inatteso restituendo liste vuote invece di lanciare.
  static LineupSnapshot? fromRpc(Object? data) {
    if (data is! Map) return null;
    return LineupSnapshot(
      teams: rowsOf(data['teams']),
      players: rowsOf(data['players']),
    );
  }

  /// Normalizza una lista di righe che arriva da PostgREST o da un jsonb in
  /// `List<JsonMap>`, scartando qualsiasi elemento non conforme.
  static List<JsonMap> rowsOf(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : const [];
}

class MatchPostGame {
  const MatchPostGame({
    required this.teamAScore,
    required this.teamBScore,
    required this.completedAt,
    required this.mvpVotingEndsAt,
    this.mvpFinalizedAt,
    required this.teams,
    required this.playerStats,
    this.ownVotePlayerId,
    this.mvpVotes,
  });
  final int teamAScore;
  final int teamBScore;
  final DateTime completedAt;
  final DateTime mvpVotingEndsAt;
  final DateTime? mvpFinalizedAt;
  final List<JsonMap> teams;
  final List<JsonMap> playerStats;
  final String? ownVotePlayerId;
  final int? mvpVotes;
}

class LastMatchSummary {
  const LastMatchSummary({
    required this.id,
    required this.title,
    required this.leagueName,
    required this.teamAScore,
    required this.teamBScore,
    required this.goals,
    required this.assists,
    this.rating,
    required this.result,
    required this.isMvp,
  });
  final String id;
  final String title;
  final String leagueName;
  final int teamAScore;
  final int teamBScore;
  final int goals;
  final int assists;
  final double? rating;
  final String result;
  final bool isMvp;
}

class DashboardData {
  const DashboardData({
    required this.profile,
    required this.stats,
    required this.unreadNotifications,
    required this.nextMatch,
    required this.leagues,
    this.lastMatch,
    this.nearby = const [],
  });

  final UserProfile profile;
  final PlayerStats stats;
  final int unreadNotifications;
  final MatchSummary? nextMatch;
  final List<LeagueSummary> leagues;
  final LastMatchSummary? lastMatch;
  final List<MatchSummary> nearby;
}

class KicklyNotification {
  const KicklyNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.link,
    required this.readAt,
    required this.createdAt,
  });

  factory KicklyNotification.fromMap(JsonMap map) => KicklyNotification(
    id: map['id'].toString(),
    type: map['type']?.toString() ?? 'info',
    title: repairText(map['title']?.toString() ?? 'Kickly'),
    body: repairText(map['body']?.toString() ?? ''),
    link: map['link']?.toString(),
    readAt: map['read_at'] == null ? null : asDate(map['read_at']),
    createdAt: asDate(map['created_at']),
  );

  final String id;
  final String type;
  final String title;
  final String body;
  final String? link;
  final DateTime? readAt;
  final DateTime createdAt;
}

class ProfileDetails {
  const ProfileDetails({
    required this.profile,
    required this.stats,
    required this.history,
    required this.form,
  });

  final UserProfile profile;
  final PlayerStats stats;
  final List<JsonMap> history;
  final List<String> form;
}
