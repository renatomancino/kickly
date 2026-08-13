"use client";

import { useMemo } from "react";
import { CalendarDays, LoaderCircle, MapPin } from "lucide-react";
import { Controller, useForm } from "react-hook-form";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { footballFormats } from "@/features/leagues/schema";
import type { MatchFormat, MatchVisibility } from "@/types/database";

import type { ManagedLeague, MatchFormDefaults } from "./types";

interface FormValues {
  leagueId: string;
  title: string;
  description: string;
  date: string;
  time: string;
  locationName: string;
  address: string;
  city: string;
  footballFormat: MatchFormat;
  maxPlayers: number;
  costTotal: number | null;
  visibility: MatchVisibility;
}

export function MatchForm({
  leagues,
  defaults,
}: {
  leagues: ManagedLeague[];
  defaults?: MatchFormDefaults;
}) {
  const router = useRouter();
  const initialLeague = leagues.find((league) => league.id === defaults?.leagueId) ?? leagues[0];
  const initialDate = useMemo(() => localInputs(defaults?.startsAt), [defaults?.startsAt]);
  const { register, control, handleSubmit, setValue, formState: { errors, isSubmitting } } = useForm<FormValues>({
    defaultValues: {
      leagueId: defaults?.leagueId ?? initialLeague?.id ?? "",
      title: defaults?.title ?? "",
      description: defaults?.description ?? "",
      date: initialDate.date,
      time: initialDate.time,
      locationName: defaults?.locationName ?? "",
      address: defaults?.address ?? "",
      city: defaults?.city ?? initialLeague?.city ?? "",
      footballFormat: defaults?.footballFormat ?? initialLeague?.footballFormat ?? "5v5",
      maxPlayers: defaults?.maxPlayers ?? formatPlayers(initialLeague?.footballFormat ?? "5v5"),
      costTotal: defaults?.costTotal ?? null,
      visibility: defaults?.visibility ?? "league_only",
    },
  });

  const onSubmit = handleSubmit(async (values) => {
    const startsAt = toIso(values.date, values.time);
    if (!startsAt) {
      toast.error("Data o orario non validi.");
      return;
    }
    const response = await fetch(defaults?.id ? `/api/matches/${defaults.id}` : "/api/matches", {
      method: defaults?.id ? "PATCH" : "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        league_id: values.leagueId,
        title: values.title,
        description: values.description,
        starts_at: startsAt,
        location_name: values.locationName,
        address: values.address,
        city: values.city,
        football_format: values.footballFormat,
        max_players: values.maxPlayers,
        cost_total: values.costTotal,
        visibility: values.visibility,
      }),
    });
    const result = (await response.json()) as { id?: string; message?: string };
    if (!response.ok) {
      toast.error(result.message ?? "Salvataggio non riuscito.");
      return;
    }
    toast.success(defaults?.id ? "Partita aggiornata." : "Partita creata.");
    router.push(`/matches/${defaults?.id ?? result.id}`);
    router.refresh();
  });

  return (
    <form className="space-y-6" onSubmit={onSubmit}>
      {leagues.length > 1 && !defaults?.id ? (
        <Field label="Lega">
          <Controller control={control} name="leagueId" render={({ field }) => (
            <Select onValueChange={(value) => {
              field.onChange(value);
              const league = leagues.find((item) => item.id === value);
              if (league) {
                setValue("city", league.city);
                setValue("footballFormat", league.footballFormat);
                setValue("maxPlayers", formatPlayers(league.footballFormat));
              }
            }} value={field.value}>
              <SelectTrigger className="h-11 w-full"><SelectValue /></SelectTrigger>
              <SelectContent>{leagues.map((league) => <SelectItem key={league.id} value={league.id}>{league.name}</SelectItem>)}</SelectContent>
            </Select>
          )} />
        </Field>
      ) : null}

      <Field error={errors.title?.message} label="Titolo">
        <Input className="h-11" placeholder="Giovedì sotto le luci" {...register("title", { required: "Inserisci il titolo.", minLength: { value: 3, message: "Inserisci almeno 3 caratteri." } })} />
      </Field>
      <div className="grid grid-cols-2 gap-4">
        <Field error={errors.date?.message} label="Data">
          <div className="relative"><CalendarDays className="pointer-events-none absolute start-3 top-3 size-4 text-muted-foreground" /><Input className="h-11 ps-10" type="date" {...register("date", { required: "Scegli la data." })} /></div>
        </Field>
        <Field error={errors.time?.message} label="Ora">
          <Input className="h-11" type="time" {...register("time", { required: "Scegli l’ora." })} />
        </Field>
      </div>
      <Field error={errors.locationName?.message} label="Luogo">
        <div className="relative"><MapPin className="pointer-events-none absolute start-3 top-3 size-4 text-muted-foreground" /><Input className="h-11 ps-10" placeholder="Centro Sportivo Aurora" {...register("locationName", { required: "Inserisci il luogo." })} /></div>
      </Field>
      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Indirizzo"><Input className="h-11" placeholder="Via Roma 10" {...register("address")} /></Field>
        <Field error={errors.city?.message} label="Città"><Input className="h-11" {...register("city", { required: "Inserisci la città." })} /></Field>
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Formato">
          <Controller control={control} name="footballFormat" render={({ field }) => (
            <Select onValueChange={(value: MatchFormat) => {
              field.onChange(value);
              setValue("maxPlayers", formatPlayers(value));
            }} value={field.value}>
              <SelectTrigger className="h-11 w-full"><SelectValue /></SelectTrigger>
              <SelectContent>{footballFormats.map((value) => <SelectItem key={value} value={value}>{value.replace("v", " vs ")}</SelectItem>)}</SelectContent>
            </Select>
          )} />
        </Field>
        <Field error={errors.maxPlayers?.message} label="Massimo giocatori">
          <Input className="h-11" max={30} min={4} type="number" {...register("maxPlayers", { valueAsNumber: true, min: { value: 4, message: "Minimo 4 giocatori." }, max: { value: 30, message: "Massimo 30 giocatori." } })} />
        </Field>
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Costo campo opzionale">
          <Input className="h-11" min={0} placeholder="60" step="0.01" type="number" {...register("costTotal", { setValueAs: (value) => value === "" ? null : Number(value) })} />
        </Field>
        <ControlledSelect control={control} label="Visibilità" name="visibility" options={[{ value: "league_only", label: "Solo lega" }, { value: "public", label: "Pubblica" }]} />
      </div>
      <Field label="Note"><Textarea className="min-h-24 resize-none" placeholder="Indicazioni utili per i giocatori…" {...register("description")} /></Field>
      <Button className="h-12 w-full rounded-xl font-bold" disabled={isSubmitting} type="submit">
        {isSubmitting ? <LoaderCircle className="animate-spin" /> : null}{defaults?.id ? "Salva modifiche" : "Crea partita"}
      </Button>
    </form>
  );
}

function Field({ label, error, children }: { label: string; error?: string; children: React.ReactNode }) {
  return <div className="space-y-2"><Label>{label}</Label>{children}{error ? <p className="text-xs text-destructive">{error}</p> : null}</div>;
}

function ControlledSelect({ control, name, label, options }: {
  control: ReturnType<typeof useForm<FormValues>>["control"];
  name: "visibility";
  label: string;
  options: { value: string; label: string }[];
}) {
  return <Field label={label}><Controller control={control} name={name} render={({ field }) => (
    <Select onValueChange={field.onChange} value={field.value}><SelectTrigger className="h-11 w-full"><SelectValue /></SelectTrigger><SelectContent>{options.map((option) => <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>)}</SelectContent></Select>
  )} /></Field>;
}

function localInputs(value?: string) {
  const date = value ? new Date(value) : new Date(Date.now() + 24 * 60 * 60 * 1000);
  if (!value) date.setHours(20, 0, 0, 0);
  return {
    date: `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`,
    time: `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`,
  };
}

function toIso(dateValue: string, timeValue: string) {
  const [year, month, day] = dateValue.split("-").map(Number);
  const [hours, minutes] = timeValue.split(":").map(Number);
  const date = new Date(year, month - 1, day, hours, minutes, 0, 0);
  if ([year, month, day, hours, minutes].some(Number.isNaN) || date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) return null;
  return date.toISOString();
}

function formatPlayers(format: MatchFormat) {
  return Number(format.split("v")[0]) * 2;
}
