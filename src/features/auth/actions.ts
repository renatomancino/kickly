"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { siteConfig } from "@/config/site";
import { hasSupabaseEnv } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

import {
  emailSchema,
  loginSchema,
  signUpSchema,
  updatePasswordSchema,
} from "./schemas";
import type { AuthActionState } from "./types";

function configError(): AuthActionState {
  return {
    status: "error",
    message: "Supabase non è ancora configurato. Consulta il README per iniziare.",
  };
}

function originFromHeaders(host: string | null, protocol: string | null) {
  if (!host) return siteConfig.url;
  return `${protocol ?? "http"}://${host}`;
}

function safeNextPath(value: FormDataEntryValue | null, fallback: string) {
  return typeof value === "string" && value.startsWith("/") && !value.startsWith("//")
    ? value
    : fallback;
}

export async function loginAction(
  _previous: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  if (!hasSupabaseEnv()) return configError();

  const parsed = loginSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return {
      status: "error",
      message: "Controlla i dati inseriti.",
      fieldErrors: parsed.error.flatten().fieldErrors,
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) {
    return {
      status: "error",
      message: "Email o password non corrette.",
    };
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Sessione non disponibile." };

  const { data: profile } = await supabase
    .from("profiles")
    .select("onboarding_completed")
    .eq("id", user.id)
    .maybeSingle();

  const next = safeNextPath(formData.get("next"), "/dashboard");
  redirect(profile?.onboarding_completed ? next : `/onboarding?next=${encodeURIComponent(next)}`);
}

export async function signUpAction(
  _previous: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  if (!hasSupabaseEnv()) return configError();

  const parsed = signUpSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return {
      status: "error",
      message: "Controlla i dati inseriti.",
      fieldErrors: parsed.error.flatten().fieldErrors,
    };
  }

  const requestHeaders = await headers();
  const origin = originFromHeaders(
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
    requestHeaders.get("x-forwarded-proto"),
  );
  const supabase = await createClient();
  const next = safeNextPath(formData.get("next"), "/onboarding");
  const onboardingDestination = `/onboarding?next=${encodeURIComponent(next)}`;
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      emailRedirectTo: `${origin}/auth/callback?next=${encodeURIComponent(onboardingDestination)}`,
    },
  });

  if (error) {
    return { status: "error", message: "Registrazione non riuscita. Riprova." };
  }

  if (data.session) redirect(onboardingDestination);

  return {
    status: "success",
    message: "Controlla la tua email per confermare l’account.",
  };
}

export async function forgotPasswordAction(
  _previous: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  if (!hasSupabaseEnv()) return configError();

  const parsed = emailSchema.safeParse(formData.get("email"));
  if (!parsed.success) {
    return { status: "error", message: "Inserisci un indirizzo email valido." };
  }

  const requestHeaders = await headers();
  const origin = originFromHeaders(
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
    requestHeaders.get("x-forwarded-proto"),
  );
  const supabase = await createClient();
  const { error } = await supabase.auth.resetPasswordForEmail(parsed.data, {
    redirectTo: `${origin}/auth/callback?next=/update-password`,
  });

  if (error) {
    return { status: "error", message: "Invio non riuscito. Attendi e riprova." };
  }

  return {
    status: "success",
    message: "Se l’account esiste, riceverai un link per reimpostare la password.",
  };
}

export async function updatePasswordAction(
  _previous: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  if (!hasSupabaseEnv()) return configError();

  const parsed = updatePasswordSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return {
      status: "error",
      message: "Controlla la nuova password.",
      fieldErrors: parsed.error.flatten().fieldErrors,
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser({
    password: parsed.data.password,
  });

  if (error) return { status: "error", message: "Il link non è più valido." };
  redirect("/dashboard");
}

export async function logoutAction() {
  if (hasSupabaseEnv()) {
    const supabase = await createClient();
    await supabase.auth.signOut();
  }
  redirect("/login");
}
