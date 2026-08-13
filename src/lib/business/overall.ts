import type { FootballRole } from "@/types/database";

export interface MatchPerformance {
  role: FootballRole;
  goals: number;
  assists: number;
  won: boolean;
  draw: boolean;
  mvp: boolean;
  cleanSheet?: boolean;
  defensiveRating?: number;
}

const roleWeights: Record<
  FootballRole,
  { goal: number; assist: number; cleanSheet: number; defense: number }
> = {
  goalkeeper: { goal: 0.08, assist: 0.08, cleanSheet: 0.38, defense: 0.08 },
  defender: { goal: 0.18, assist: 0.12, cleanSheet: 0.26, defense: 0.07 },
  midfielder: { goal: 0.18, assist: 0.2, cleanSheet: 0.08, defense: 0.04 },
  forward: { goal: 0.26, assist: 0.16, cleanSheet: 0.03, defense: 0.02 },
};

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

/**
 * Calculates a deliberately low-volatility rating change for one match.
 * Persistence and season/recent-form smoothing belong to the database service.
 */
export function calculateRatingDelta(performance: MatchPerformance): number {
  const weights = roleWeights[performance.role];
  const resultScore = performance.won ? 0.16 : performance.draw ? 0.04 : -0.12;
  const contribution =
    Math.min(performance.goals, 4) * weights.goal +
    Math.min(performance.assists, 4) * weights.assist +
    (performance.mvp ? 0.24 : 0) +
    (performance.cleanSheet ? weights.cleanSheet : 0) +
    clamp((performance.defensiveRating ?? 5) - 5, -4, 5) * weights.defense;

  return Math.round(clamp(resultScore + contribution - 0.08, -0.8, 0.8) * 100) / 100;
}

export function applyRatingDelta(currentRating: number, delta: number): number {
  return Math.round(clamp(currentRating + clamp(delta, -1, 1), 1, 99) * 10) / 10;
}
