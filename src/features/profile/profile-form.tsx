"use client";

import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { Camera, Check, LoaderCircle } from "lucide-react";
import { Controller, useForm } from "react-hook-form";
import { useRouter } from "next/navigation";

import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ProfileRow } from "@/types/database";

import {
  footballRoles,
  footLabels,
  levelLabels,
  preferredFeet,
  profileSchema,
  roleLabels,
  skillLevels,
  type ProfileInput,
} from "./schema";

export function ProfileForm({
  profile,
  mode,
  next,
}: {
  profile?: ProfileRow | null;
  mode: "onboarding" | "edit";
  next?: string;
}) {
  const router = useRouter();
  const [message, setMessage] = useState("");
  const [avatar, setAvatar] = useState<File | null>(null);
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isSubmitting },
  } = useForm<ProfileInput>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      first_name: profile?.first_name ?? "",
      last_name: profile?.last_name ?? "",
      username: profile?.username?.startsWith("player_") ? "" : profile?.username ?? "",
      birth_date: profile?.birth_date ?? "",
      city: profile?.city ?? "",
      primary_position: profile?.primary_position ?? "midfielder",
      secondary_position: profile?.secondary_position ?? "",
      preferred_foot: profile?.preferred_foot ?? "right",
      skill_level: profile?.skill_level ?? "amateur",
      profile_public: profile?.profile_public ?? true,
    },
  });

  const onSubmit = handleSubmit(async (values) => {
    setMessage("");
    const body = new FormData();
    Object.entries(values).forEach(([key, value]) => body.set(key, String(value ?? "")));
    if (avatar) body.set("avatar", avatar);

    const response = await fetch("/api/profile", { method: "POST", body });
    const result = (await response.json()) as { message?: string };
    if (!response.ok) {
      setMessage(result.message ?? "Salvataggio non riuscito.");
      return;
    }

    if (mode === "onboarding") {
      router.push(next?.startsWith("/") && !next.startsWith("//") ? next : "/dashboard");
    } else {
      setMessage("Profilo aggiornato.");
      router.refresh();
    }
  });

  return (
    <form className="space-y-7" onSubmit={onSubmit}>
      <div className="flex items-center gap-4 rounded-2xl border bg-card/70 p-4">
        <div className="grid size-16 shrink-0 place-items-center rounded-2xl bg-primary/10 text-primary">
          <Camera className="size-6" />
        </div>
        <div className="min-w-0 flex-1">
          <Label htmlFor="avatar">Foto profilo</Label>
          <p className="mt-1 text-xs text-muted-foreground">JPG, PNG o WebP · max 5 MB</p>
          <Input
            accept="image/jpeg,image/png,image/webp"
            className="mt-3 h-auto cursor-pointer py-2 text-xs"
            id="avatar"
            onChange={(event) => setAvatar(event.target.files?.[0] ?? null)}
            type="file"
          />
        </div>
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <TextField label="Nome" error={errors.first_name?.message} {...register("first_name")} />
        <TextField label="Cognome" error={errors.last_name?.message} {...register("last_name")} />
        <TextField label="Username" error={errors.username?.message} prefix="@" {...register("username")} />
        <TextField label="Data di nascita (opzionale)" error={errors.birth_date?.message} type="date" {...register("birth_date")} />
        <TextField className="sm:col-span-2" label="Città" error={errors.city?.message} {...register("city")} />
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <SelectField control={control} label="Ruolo principale" name="primary_position" items={footballRoles.map((value) => ({ value, label: roleLabels[value] }))} />
        <SelectField control={control} label="Ruolo secondario" name="secondary_position" optional items={footballRoles.map((value) => ({ value, label: roleLabels[value] }))} />
        <SelectField control={control} label="Piede preferito" name="preferred_foot" items={preferredFeet.map((value) => ({ value, label: footLabels[value] }))} />
        <SelectField control={control} label="Livello" name="skill_level" items={skillLevels.map((value) => ({ value, label: levelLabels[value] }))} />
      </div>

      <label className="flex cursor-pointer items-start gap-3 rounded-2xl border bg-card/70 p-4">
        <input className="mt-1 size-4 accent-[var(--primary)]" type="checkbox" {...register("profile_public")} />
        <span>
          <span className="block text-sm font-medium">Profilo pubblico</span>
          <span className="mt-1 block text-xs leading-5 text-muted-foreground">Mostra player card e statistiche nelle aree pubbliche.</span>
        </span>
      </label>

      {message ? (
        <Alert className="border-primary/30 bg-primary/5">
          <Check className="text-primary" />
          <AlertDescription>{message}</AlertDescription>
        </Alert>
      ) : null}

      <Button className="h-12 w-full rounded-xl font-bold" disabled={isSubmitting} type="submit">
        {isSubmitting ? <LoaderCircle className="animate-spin" /> : null}
        {mode === "onboarding" ? "Entra in Kickly" : "Salva modifiche"}
      </Button>
    </form>
  );
}

function TextField({
  label,
  error,
  prefix,
  className,
  ...props
}: { label: string; error?: string; prefix?: string; className?: string } & React.ComponentProps<typeof Input>) {
  const id = props.name;
  return (
    <div className={className}>
      <Label htmlFor={id}>{label}</Label>
      <div className="relative mt-2">
        {prefix ? <span className="absolute start-3 top-1/2 -translate-y-1/2 text-muted-foreground">{prefix}</span> : null}
        <Input className={prefix ? "h-11 ps-8" : "h-11"} id={id} aria-invalid={Boolean(error)} {...props} />
      </div>
      {error ? <p className="mt-1.5 text-xs text-destructive">{error}</p> : null}
    </div>
  );
}

function SelectField({
  control,
  name,
  label,
  items,
  optional = false,
}: {
  control: ReturnType<typeof useForm<ProfileInput>>["control"];
  name: "primary_position" | "secondary_position" | "preferred_foot" | "skill_level";
  label: string;
  items: { value: string; label: string }[];
  optional?: boolean;
}) {
  return (
    <div>
      <Label>{label}</Label>
      <Controller
        control={control}
        name={name}
        render={({ field, fieldState }) => (
          <>
            <Select onValueChange={field.onChange} value={field.value || "none"}>
              <SelectTrigger className="mt-2 h-11 w-full" aria-invalid={fieldState.invalid}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {optional ? <SelectItem value="none">Nessuno</SelectItem> : null}
                {items.map((item) => <SelectItem key={item.value} value={item.value}>{item.label}</SelectItem>)}
              </SelectContent>
            </Select>
            {fieldState.error ? <p className="mt-1.5 text-xs text-destructive">{fieldState.error.message}</p> : null}
          </>
        )}
      />
    </div>
  );
}
