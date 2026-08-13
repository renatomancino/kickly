export interface LeaderboardPlayer {
  userId: string;
  username: string;
  name: string;
  avatarUrl: string | null;
  matches: number;
  goals: number;
  assists: number;
  mvp: number;
  overall: number;
}

export interface LeagueLeaderboards {
  goals: LeaderboardPlayer[];
  assists: LeaderboardPlayer[];
  mvp: LeaderboardPlayer[];
  appearances: LeaderboardPlayer[];
  overall: LeaderboardPlayer[];
}
