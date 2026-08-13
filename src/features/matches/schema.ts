import { z } from "zod";

import { footballFormats } from "@/features/leagues/schema";

export const matchSchema = z.object({
  league_id: z.string().uuid(),
  title: z.string().trim().min(3, "Inserisci almeno 3 caratteri.").max(100),
  description: z.string().trim().max(1000).optional().or(z.literal("")),
  starts_at: z.iso.datetime(),
  location_name: z.string().trim().min(2, "Inserisci il luogo.").max(120),
  address: z.string().trim().max(180).optional().or(z.literal("")),
  city: z.string().trim().min(2, "Inserisci la città.").max(80),
  football_format: z.enum(footballFormats),
  max_players: z.number().int().min(4).max(30),
  cost_total: z.number().min(0).max(10000).nullable(),
  visibility: z.enum(["league_only", "public"]),
});

export const responseSchema = z.object({
  response: z.enum(["going", "maybe", "not_going"]),
});

const lineupTeamSchema = z.union([z.literal(1), z.literal(2)]);

export const lineupActionSchema = z.discriminatedUnion("action", [
  z.object({
    action: z.literal("claim"),
    team_number: lineupTeamSchema,
    slot_key: z.string().regex(/^(gk|p([1-9]|10))$/),
    wants_captain: z.boolean().default(false),
  }),
  z.object({ action: z.literal("release") }),
  z.object({
    action: z.literal("formation"),
    team_number: lineupTeamSchema,
    formation: z.string().regex(/^\d-\d-\d$/),
  }),
]);

export const adminStateSchema = z.object({
  action: z.enum(["cancel", "close", "reopen"]),
});

export const matchReminderSchema = z.object({
  body: z.string().trim().min(3, "Inserisci un messaggio di almeno 3 caratteri.").max(500),
});

const postGamePlayerSchema = z.object({
  user_id: z.string().uuid(),
  goals: z.number().int().min(0).max(99),
  assists: z.number().int().min(0).max(99),
});

export const postGameSchema = z.object({
  team_a_players: z.array(z.string().uuid()).min(1),
  team_b_players: z.array(z.string().uuid()).min(1),
  score_a: z.number().int().min(0).max(99),
  score_b: z.number().int().min(0).max(99),
  player_totals: z.array(postGamePlayerSchema).min(2),
});

export const mvpVoteSchema = z.object({
  player_id: z.string().uuid(),
});

export type MatchInput = z.infer<typeof matchSchema>;
