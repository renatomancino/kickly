export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type FootballRole =
  | "goalkeeper"
  | "defender"
  | "midfielder"
  | "forward";
export type PreferredFoot = "left" | "right" | "both";
export type SkillLevel = "beginner" | "amateur" | "intermediate" | "advanced";
export type MatchFormat = "5v5" | "7v7" | "8v8" | "10v10" | "11v11";
export type AttendanceStatus = "going" | "not_going" | "maybe" | "waitlist";
export type MatchVisibility = "league_only" | "public";
export type MatchStatus = "draft" | "open" | "full" | "cancelled" | "completed";
export type MatchResult = "win" | "draw" | "loss";

export interface ProfileRow {
  id: string;
  first_name: string | null;
  last_name: string | null;
  username: string;
  birth_date: string | null;
  city: string | null;
  avatar_path: string | null;
  primary_position: FootballRole | null;
  secondary_position: FootballRole | null;
  preferred_foot: PreferredFoot | null;
  skill_level: SkillLevel | null;
  overall: number;
  onboarding_completed: boolean;
  profile_public: boolean;
  timezone: string;
  created_at: string;
  updated_at: string;
}

interface BaseTable<Row, Insert = Partial<Row>, Update = Partial<Row>> {
  Row: Row;
  Insert: Insert;
  Update: Update;
  Relationships: [];
}

export interface Database {
  public: {
    Tables: {
      profiles: BaseTable<ProfileRow, Partial<ProfileRow> & { id: string }>;
      leagues: BaseTable<{
        id: string;
        owner_id: string;
        name: string;
        slug: string;
        description: string | null;
        logo_url: string | null;
        city: string;
        country: string;
        visibility: "private" | "public";
        football_format: MatchFormat;
        max_members: number;
        invite_code: string;
        created_at: string;
        updated_at: string;
      }>;
      league_members: BaseTable<{
        id: string;
        league_id: string;
        user_id: string;
        role: "owner" | "admin" | "member";
        status: "pending" | "active" | "banned";
        joined_at: string;
        created_at: string;
      }>;
      matches: BaseTable<{
        id: string;
        league_id: string;
        created_by: string;
        title: string;
        description: string | null;
        starts_at: string;
        location_name: string;
        address: string | null;
        city: string;
        latitude: number | null;
        longitude: number | null;
        football_format: MatchFormat;
        max_players: number;
        cost_total: number | null;
        visibility: MatchVisibility;
        status: MatchStatus;
        team_a_score: number | null;
        team_b_score: number | null;
        completed_at: string | null;
        mvp_voting_ends_at: string | null;
        mvp_finalized_at: string | null;
        registration_closed_at: string | null;
        created_at: string;
        updated_at: string;
      }>;
      match_participants: BaseTable<{
        id: string;
        match_id: string;
        user_id: string;
        response: AttendanceStatus;
        checked_in: boolean;
        joined_at: string;
        updated_at: string;
      }>;
      match_lineup_teams: BaseTable<{
        match_id: string;
        team_number: number;
        formation: string;
        captain_user_id: string | null;
        created_at: string;
        updated_at: string;
      }>;
      match_lineup_players: BaseTable<{
        match_id: string;
        user_id: string;
        team_number: number;
        slot_key: string;
        created_at: string;
        updated_at: string;
      }>;
      match_teams: BaseTable<{
        id: string;
        match_id: string;
        name: string;
        team_number: number;
        created_at: string;
      }>;
      match_team_players: BaseTable<{
        id: string;
        match_id: string;
        team_id: string;
        user_id: string;
        created_at: string;
      }>;
      match_events: BaseTable<{
        id: string;
        match_id: string;
        team_id: string;
        player_id: string;
        event_type: "goal" | "assist";
        quantity: number;
        created_by: string;
        created_at: string;
        updated_at: string;
      }>;
      player_match_stats: BaseTable<{
        id: string;
        match_id: string;
        user_id: string;
        team_id: string;
        goals: number;
        assists: number;
        result: MatchResult;
        is_mvp: boolean;
        match_rating: number | null;
        previous_overall: number | null;
        new_overall: number | null;
        rating_delta: number;
        created_at: string;
        updated_at: string;
      }>;
      mvp_votes: BaseTable<{
        id: string;
        match_id: string;
        voter_id: string;
        voted_player_id: string;
        created_at: string;
      }>;
      player_stats: BaseTable<{
        id: string;
        user_id: string;
        league_id: string | null;
        season_id: string | null;
        matches_played: number;
        wins: number;
        draws: number;
        losses: number;
        goals: number;
        assists: number;
        mvp_awards: number;
        current_streak: number;
        overall: number;
        updated_at: string;
      }>;
      player_rating_history: BaseTable<{
        id: string;
        user_id: string;
        match_id: string | null;
        previous_rating: number;
        new_rating: number;
        delta: number;
        reason: string;
        created_at: string;
      }>;
      notifications: BaseTable<{
        id: string;
        user_id: string;
        type: string;
        title: string;
        body: string;
        link: string | null;
        metadata: Json;
        read_at: string | null;
        dedupe_key: string | null;
        push_sent_at: string | null;
        created_at: string;
      }>;
      notification_preferences: BaseTable<{
        user_id: string;
        match_created: boolean;
        match_updates: boolean;
        match_reminders: boolean;
        waitlist: boolean;
        mvp: boolean;
        rating: boolean;
        league_updates: boolean;
        push_enabled: boolean;
        created_at: string;
        updated_at: string;
      }>;
      push_subscriptions: BaseTable<{
        id: string;
        user_id: string;
        endpoint: string;
        p256dh: string;
        auth: string;
        user_agent: string | null;
        device_name: string | null;
        last_used_at: string | null;
        disabled_at: string | null;
        created_at: string;
      }>;
    };
    Views: Record<string, never>;
    Functions: {
      create_match: {
        Args: {
          target_league: string;
          match_title: string;
          match_description: string;
          match_starts_at: string;
          match_location_name: string;
          match_address: string;
          match_city: string;
          match_football_format: MatchFormat;
          match_max_players: number;
          match_cost_total: number | null;
          match_visibility: MatchVisibility;
        };
        Returns: string;
      };
      update_match_details: {
        Args: {
          target_match: string;
          match_title: string;
          match_description: string;
          match_starts_at: string;
          match_location_name: string;
          match_address: string;
          match_city: string;
          match_football_format: MatchFormat;
          match_max_players: number;
          match_cost_total: number | null;
          match_visibility: MatchVisibility;
        };
        Returns: undefined;
      };
      set_match_admin_state: {
        Args: { target_match: string; target_action: string };
        Returns: { match_status: MatchStatus; closed_at: string | null }[];
      };
      set_match_response: {
        Args: { target_match: string; target_response: AttendanceStatus };
        Returns: {
          actual_response: AttendanceStatus;
          going_count: number;
          waitlist_position: number | null;
          match_status: MatchStatus;
        }[];
      };
      set_match_lineup_slot: {
        Args: {
          target_match: string;
          target_team: number;
          target_slot: string;
          wants_captain?: boolean;
        };
        Returns: Json;
      };
      leave_match_lineup: {
        Args: { target_match: string };
        Returns: Json;
      };
      set_match_lineup_formation: {
        Args: { target_match: string; target_team: number; target_formation: string };
        Returns: Json;
      };
      finalize_match: {
        Args: {
          target_match: string;
          team_a_players: string[];
          team_b_players: string[];
          score_a: number;
          score_b: number;
          player_totals: Json;
        };
        Returns: undefined;
      };
      cast_mvp_vote: {
        Args: { target_match: string; target_player: string };
        Returns: undefined;
      };
      finalize_match_mvp: {
        Args: { target_match: string };
        Returns: string;
      };
      [key: string]: { Args: Record<string, unknown>; Returns: unknown };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
