import { z } from "zod";

export const footballFormats = ["5v5", "7v7", "8v8", "10v10", "11v11"] as const;

export const leagueSchema = z.object({
  name: z.string().trim().min(3, "Inserisci almeno 3 caratteri.").max(80),
  description: z.string().trim().max(500).optional().or(z.literal("")),
  city: z.string().trim().min(2, "Inserisci la città.").max(80),
  country: z.string().trim().length(2).toUpperCase(),
  visibility: z.enum(["private", "public"]),
  football_format: z.enum(footballFormats),
  max_members: z.number().int().min(2).max(500),
});

export const inviteCodeSchema = z
  .string()
  .trim()
  .min(6, "Il codice deve avere almeno 6 caratteri.")
  .max(16)
  .regex(/^[A-Za-z0-9]+$/, "Il codice contiene caratteri non validi.")
  .transform((value) => value.toUpperCase());

export const memberActionSchema = z.object({
  action: z.enum(["promote", "demote", "remove", "transfer"]),
});

export const deleteLeagueSchema = z.object({
  confirmation: z.string().trim().min(1),
});

export const leagueCommunicationSchema = z.object({
  title: z.string().trim().min(3, "Inserisci un titolo di almeno 3 caratteri.").max(120),
  body: z.string().trim().min(3, "Inserisci un messaggio di almeno 3 caratteri.").max(500),
  pinned: z.boolean().default(false),
});

export type LeagueInput = z.infer<typeof leagueSchema>;
