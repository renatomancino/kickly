import { z } from "zod";

export const footballRoles = [
  "goalkeeper",
  "defender",
  "midfielder",
  "forward",
] as const;
export const preferredFeet = ["left", "right", "both"] as const;
export const skillLevels = [
  "beginner",
  "amateur",
  "intermediate",
  "advanced",
] as const;

export const profileSchema = z
  .object({
    first_name: z.string().trim().min(2, "Inserisci almeno 2 caratteri.").max(50),
    last_name: z.string().trim().min(2, "Inserisci almeno 2 caratteri.").max(50),
    username: z
      .string()
      .trim()
      .toLowerCase()
      .min(3, "Usa almeno 3 caratteri.")
      .max(24)
      .regex(/^[a-z0-9_]+$/, "Usa solo lettere, numeri e underscore."),
    birth_date: z.string().optional(),
    city: z.string().trim().min(2, "Inserisci la tua città.").max(80),
    primary_position: z.enum(footballRoles),
    secondary_position: z.enum(footballRoles).optional().or(z.literal("")),
    preferred_foot: z.enum(preferredFeet),
    skill_level: z.enum(skillLevels),
    profile_public: z.boolean(),
  })
  .refine(
    (values) =>
      !values.secondary_position ||
      values.secondary_position !== values.primary_position,
    {
      message: "Scegli un ruolo secondario diverso.",
      path: ["secondary_position"],
    },
  );

export type ProfileInput = z.infer<typeof profileSchema>;

export const roleLabels = {
  goalkeeper: "Portiere",
  defender: "Difensore",
  midfielder: "Centrocampista",
  forward: "Attaccante",
} satisfies Record<(typeof footballRoles)[number], string>;

export const footLabels = {
  left: "Sinistro",
  right: "Destro",
  both: "Entrambi",
} satisfies Record<(typeof preferredFeet)[number], string>;

export const levelLabels = {
  beginner: "Principiante",
  amateur: "Amatoriale",
  intermediate: "Intermedio",
  advanced: "Avanzato",
} satisfies Record<(typeof skillLevels)[number], string>;
