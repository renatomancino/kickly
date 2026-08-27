import 'package:flutter_test/flutter_test.dart';
import 'package:kickly_app/core/config/app_config.dart';
import 'package:kickly_app/data/models.dart';

void main() {
  test(
    'AppConfig accepts a valid Supabase endpoint and rejects placeholders',
    () {
      const configured = AppConfig(
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: 'sb_publishable_test',
      );
      const missing = AppConfig(supabaseUrl: '', supabasePublishableKey: '');

      expect(configured.hasSupabase, isTrue);
      expect(missing.hasSupabase, isFalse);
    },
  );

  test('LeagueSummary maps the existing Supabase RPC shape', () {
    final league = LeagueSummary.fromRpc({
      'id': 'league-id',
      'name': 'Test League',
      'slug': 'test-league',
      'city': 'Roma',
      'country': 'Italia',
      'visibility': 'private',
      'football_format': '7v7',
      'max_members': 28,
      'member_count': 13,
      'current_user_role': 'admin',
    });

    expect(league.memberCount, 13);
    expect(league.canManage, isTrue);
    expect(league.footballFormat, '7v7');
  });

  test('PlayerStats computes win rate without dividing by zero', () {
    expect(const PlayerStats().winRate, 0);
    expect(const PlayerStats(matches: 4, wins: 3).winRate, 75);
  });

  test('MatchSummary recognises completed matches as past', () {
    final match = MatchSummary(
      id: 'match-id',
      leagueId: 'league-id',
      leagueName: 'League',
      leagueSlug: 'league',
      title: 'Finale',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      locationName: 'Campo',
      city: 'Roma',
      footballFormat: '5v5',
      maxPlayers: 10,
      goingCount: 10,
      status: 'completed',
      visibility: 'league_only',
      registrationClosedAt: null,
      currentResponse: 'going',
      isLeagueMember: true,
    );

    expect(match.isPast, isTrue);
  });

  test('AccountDeletionBlocker.fromMap legge la forma restituita da get_account_deletion_blockers', () {
    final blocker = AccountDeletionBlocker.fromMap({
      'league_id': 'league-id',
      'league_slug': 'calcetto-del-giovedi',
      'league_name': 'Calcetto del giovedì',
      'active_member_count': 8,
    });

    expect(blocker.leagueId, 'league-id');
    expect(blocker.leagueSlug, 'calcetto-del-giovedi');
    expect(blocker.leagueName, 'Calcetto del giovedì');
    expect(blocker.activeMemberCount, 8);
  });
}
