"use client";

import { useActionState } from "react";
import Link from "next/link";
import { AlertCircle, ArrowRight, CheckCircle2, LoaderCircle } from "lucide-react";

import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import {
  forgotPasswordAction,
  loginAction,
  signUpAction,
  updatePasswordAction,
} from "./actions";
import { initialAuthState } from "./types";

type Variant = "login" | "signup" | "forgot" | "update";

const content: Record<Variant, { title: string; description: string; cta: string }> = {
  login: {
    title: "Bentornato in campo",
    description: "Accedi per vedere la prossima partita e le tue statistiche.",
    cta: "Accedi",
  },
  signup: {
    title: "Crea il tuo profilo",
    description: "La tua prossima partita comincia da qui.",
    cta: "Crea account",
  },
  forgot: {
    title: "Recupera l’accesso",
    description: "Ti invieremo un link sicuro per scegliere una nuova password.",
    cta: "Invia link",
  },
  update: {
    title: "Nuova password",
    description: "Scegli una password sicura per il tuo account Kickly.",
    cta: "Aggiorna password",
  },
};

const actions = {
  login: loginAction,
  signup: signUpAction,
  forgot: forgotPasswordAction,
  update: updatePasswordAction,
};

export function AuthForm({ variant, next }: { variant: Variant; next?: string }) {
  const [state, formAction, pending] = useActionState(
    actions[variant],
    initialAuthState,
  );
  const copy = content[variant];
  const hasEmail = variant !== "update";
  const hasPassword = variant === "login" || variant === "signup" || variant === "update";
  const needsConfirmation = variant === "signup" || variant === "update";

  return (
    <div className="w-full max-w-md">
      <div className="mb-8">
        <p className="mb-3 text-xs font-semibold tracking-[0.22em] text-primary uppercase">
          Your game. Your story.
        </p>
        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">{copy.title}</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">{copy.description}</p>
      </div>

      <form action={formAction} className="space-y-5">
        {next ? <input name="next" type="hidden" value={next} /> : null}
        {hasEmail ? (
          <Field label="Email" name="email" type="email" error={state.fieldErrors?.email?.[0]} />
        ) : null}
        {hasPassword ? (
          <Field
            label={variant === "update" ? "Nuova password" : "Password"}
            name="password"
            type="password"
            autoComplete={variant === "login" ? "current-password" : "new-password"}
            error={state.fieldErrors?.password?.[0]}
          />
        ) : null}
        {needsConfirmation ? (
          <Field
            label="Conferma password"
            name="confirmPassword"
            type="password"
            autoComplete="new-password"
            error={state.fieldErrors?.confirmPassword?.[0]}
          />
        ) : null}

        {variant === "login" ? (
          <div className="flex justify-end">
            <Link className="text-sm text-muted-foreground hover:text-foreground" href="/forgot-password">
              Password dimenticata?
            </Link>
          </div>
        ) : null}

        {state.message ? (
          <Alert
            variant={state.status === "error" ? "destructive" : "default"}
            className={state.status === "success" ? "border-primary/30 bg-primary/5" : undefined}
          >
            {state.status === "error" ? <AlertCircle /> : <CheckCircle2 className="text-primary" />}
            <AlertDescription>{state.message}</AlertDescription>
          </Alert>
        ) : null}

        <Button className="h-12 w-full rounded-xl text-sm font-bold" disabled={pending} type="submit">
          {pending ? <LoaderCircle className="animate-spin" /> : null}
          {copy.cta}
          {!pending ? <ArrowRight /> : null}
        </Button>
      </form>


      <p className="mt-7 text-center text-sm text-muted-foreground">
        {variant === "login" ? (
          <>Non hai un account? <Link className="font-semibold text-foreground hover:text-primary" href={next ? `/sign-up?next=${encodeURIComponent(next)}` : "/sign-up"}>Registrati</Link></>
        ) : variant === "signup" ? (
          <>Hai già un account? <Link className="font-semibold text-foreground hover:text-primary" href={next ? `/login?next=${encodeURIComponent(next)}` : "/login"}>Accedi</Link></>
        ) : (
          <Link className="font-semibold text-foreground hover:text-primary" href="/login">Torna al login</Link>
        )}
      </p>
    </div>
  );
}


function Field({
  label,
  name,
  error,
  ...props
}: {
  label: string;
  name: string;
  error?: string;
} & React.ComponentProps<typeof Input>) {
  const errorId = `${name}-error`;
  return (
    <div className="space-y-2">
      <Label htmlFor={name}>{label}</Label>
      <Input
        aria-describedby={error ? errorId : undefined}
        aria-invalid={Boolean(error)}
        className="h-12 rounded-xl bg-input/40 px-4"
        id={name}
        name={name}
        required
        {...props}
      />
      {error ? <p className="text-xs text-destructive" id={errorId}>{error}</p> : null}
    </div>
  );
}
