"use client";

import { useEffect, useMemo, useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { Camera, LoaderCircle } from "lucide-react";
import { Controller, useForm } from "react-hook-form";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

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
import { Textarea } from "@/components/ui/textarea";

import { LeagueLogo } from "./league-logo";
import { footballFormats, leagueSchema, type LeagueInput } from "./schema";
import type { LeagueDetail } from "./types";

export function LeagueForm({
  league,
  onSaved,
}: {
  league?: LeagueDetail;
  onSaved?: () => void;
}) {
  const router = useRouter();
  const [logo, setLogo] = useState<File | null>(null);
  const previewUrl = useMemo(() => (logo ? URL.createObjectURL(logo) : null), [logo]);
  useEffect(() => () => { if (previewUrl) URL.revokeObjectURL(previewUrl); }, [previewUrl]);
  const {
    register,
    control,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LeagueInput>({
    resolver: zodResolver(leagueSchema),
    defaultValues: {
      name: league?.name ?? "",
      description: league?.description ?? "",
      city: league?.city ?? "",
      country: league?.country ?? "IT",
      visibility: league?.visibility ?? "private",
      football_format: league?.footballFormat ?? "5v5",
      max_members: league?.maxMembers ?? 30,
    },
  });

  const onSubmit = handleSubmit(async (values) => {
    const body = new FormData();
    Object.entries(values).forEach(([key, value]) => body.set(key, String(value ?? "")));
    if (logo) body.set("logo", logo);
    const response = await fetch(league ? `/api/leagues/${league.id}` : "/api/leagues", {
      method: league ? "PATCH" : "POST",
      body,
    });
    const result = (await response.json()) as { message?: string; slug?: string };
    if (!response.ok) {
      toast.error(result.message ?? "Operazione non riuscita.");
      return;
    }
    toast.success(league ? "Lega aggiornata." : "Lega creata. Sei l’owner!");
    if (league) {
      onSaved?.();
      router.refresh();
    } else if (result.slug) {
      router.push(`/leagues/${result.slug}`);
    }
  });

  return (
    <form className="space-y-6" onSubmit={onSubmit}>
      <div className="flex items-center gap-4 rounded-2xl border bg-card/60 p-4">
        <LeagueLogo
          className="size-16 rounded-2xl"
          name={league?.name ?? "nuova lega"}
          url={previewUrl ?? league?.logoUrl ?? null}
        />
        <div className="min-w-0 flex-1">
          <Label htmlFor="league-logo">Logo lega</Label>
          <p className="mt-1 text-xs text-muted-foreground">JPG, PNG o WebP · max 5 MB</p>
          <label className="mt-3 inline-flex cursor-pointer items-center gap-2 text-xs font-semibold text-primary" htmlFor="league-logo">
            <Camera className="size-4" /> Scegli immagine
          </label>
          <Input
            accept="image/jpeg,image/png,image/webp"
            className="sr-only"
            id="league-logo"
            onChange={(event) => setLogo(event.target.files?.[0] ?? null)}
            type="file"
          />
        </div>
      </div>

      <Field label="Nome lega" error={errors.name?.message}>
        <Input className="h-11" placeholder="Calcetto del Giovedì" {...register("name")} />
      </Field>
      <Field label="Descrizione" error={errors.description?.message}>
        <Textarea className="min-h-24 resize-none" placeholder="Racconta in poche righe lo spirito della lega…" {...register("description")} />
      </Field>
      <div className="grid gap-5 sm:grid-cols-[1fr_110px]">
        <Field label="Città" error={errors.city?.message}>
          <Input className="h-11" placeholder="Milano" {...register("city")} />
        </Field>
        <Field label="Paese" error={errors.country?.message}>
          <Input className="h-11 uppercase" maxLength={2} {...register("country")} />
        </Field>
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <ControlledSelect
          control={control}
          label="Privacy"
          name="visibility"
          options={[{ value: "private", label: "Privata" }, { value: "public", label: "Pubblica" }]}
        />
        <ControlledSelect
          control={control}
          label="Formato"
          name="football_format"
          options={footballFormats.map((format) => ({ value: format, label: format.replace("v", " vs ") }))}
        />
      </div>
      <Field label="Massimo membri" error={errors.max_members?.message}>
        <Input className="h-11" max={500} min={2} type="number" {...register("max_members", { valueAsNumber: true })} />
      </Field>

      <Button className="h-12 w-full rounded-xl font-bold" disabled={isSubmitting} type="submit">
        {isSubmitting ? <LoaderCircle className="animate-spin" /> : null}
        {league ? "Salva impostazioni" : "Crea lega"}
      </Button>
    </form>
  );
}

function Field({ label, error, children }: { label: string; error?: string; children: React.ReactNode }) {
  return <div className="space-y-2"><Label>{label}</Label>{children}{error ? <p className="text-xs text-destructive">{error}</p> : null}</div>;
}

function ControlledSelect({
  control,
  name,
  label,
  options,
}: {
  control: ReturnType<typeof useForm<LeagueInput>>["control"];
  name: "visibility" | "football_format";
  label: string;
  options: { value: string; label: string }[];
}) {
  return (
    <div className="space-y-2">
      <Label>{label}</Label>
      <Controller
        control={control}
        name={name}
        render={({ field }) => (
          <Select onValueChange={field.onChange} value={field.value}>
            <SelectTrigger className="h-11 w-full"><SelectValue /></SelectTrigger>
            <SelectContent>{options.map((option) => <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>)}</SelectContent>
          </Select>
        )}
      />
    </div>
  );
}
