import type { AttendanceStatus, FootballRole, MatchFormat } from "@/types/database";

export interface DashboardLeague {
  id: string;
  name: string;
  slug: string;
  logoUrl: string | null;
  city: string;
  members: number;
  format: MatchFormat;
  role: "owner" | "admin" | "member";
  nextMatchAt: string | null;
}

export interface DashboardMatch {
  id: string;
  leagueName: string;
  title: string;
  startsAt: string;
  venueName: string;
  city: string;
  format: MatchFormat;
  going: number;
  maxPlayers: number;
  participation: AttendanceStatus | null;
  distanceKm?: number;
}

export interface DashboardStats {
  matches: number;
  goals: number;
  assists: number;
  mvp: number;
  overall: number;
}

export interface DashboardLastMatch {
  id: string;
  title: string;
  leagueName: string;
  teamAScore: number;
  teamBScore: number;
  goals: number;
  assists: number;
  rating: number | null;
  result: "win" | "draw" | "loss";
  isMvp: boolean;
}

export interface DashboardData {
  source: "live" | "demo";
  firstName: string;
  username: string;
  role: FootballRole | null;
  avatarUrl: string | null;
  timezone: string;
  unreadNotifications: number;
  nextMatch: DashboardMatch | null;
  lastMatch: DashboardLastMatch | null;
  leagues: DashboardLeague[];
  stats: DashboardStats;
  nearby: DashboardMatch[];
}
