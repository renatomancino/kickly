import { z } from "zod";

export const emailSchema = z.email("Inserisci un indirizzo email valido.");

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(8, "La password deve avere almeno 8 caratteri."),
});

export const signUpSchema = loginSchema
  .extend({
    confirmPassword: z.string(),
  })
  .refine((values) => values.password === values.confirmPassword, {
    message: "Le password non coincidono.",
    path: ["confirmPassword"],
  });

export const passwordSchema = z
  .string()
  .min(8, "Usa almeno 8 caratteri.")
  .regex(/[A-Z]/, "Aggiungi almeno una lettera maiuscola.")
  .regex(/[0-9]/, "Aggiungi almeno un numero.");

export const updatePasswordSchema = z
  .object({
    password: passwordSchema,
    confirmPassword: z.string(),
  })
  .refine((values) => values.password === values.confirmPassword, {
    message: "Le password non coincidono.",
    path: ["confirmPassword"],
  });
