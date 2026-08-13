"use client";

import { useState } from "react";
import { ArrowRight, CheckCircle2, LoaderCircle, MapPin, Search, UsersRound } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { LeagueLogo } from "./league-logo";
import type { InvitePreview } from "./types";

interface RawPreview {
  id: string;
  name: string;
  slug: string;
  logo_url: string | null;
  city: string;
  country: string;
  visibility: "private" | "public";
  football_format: "5v5" | "7v7" | "8v8" | "11v11";
  max_members: number;
  member_count: number;
  already_member: boolean;
}

export function JoinLeagueSearch() {
  const [code, setCode] = useState("");
  const [preview, setPreview] = useState<InvitePreview | null>(null);
  const [loading, setLoading] = useState(false);

  async function findLeague(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setPreview(null);
    const response = await fetch(`/api/leagues/join?code=${encodeURIComponent(code)}`);
    const result = (await response.json()) as RawPreview & { message?: string };
    setLoading(false);
    if (!response.ok) {
      toast.error(result.message ?? "Codice non valido.");
      return;
    }
    setPreview({
      id: result.id,
      name: result.name,
      slug: result.slug,
      logoUrl: result.logo_url,
      city: result.city,
      country: result.country,
      visibility: result.visibility,
      footballFormat: result.football_format,
      maxMembers: result.max_members,
      memberCount: Number(result.member_count),
      alreadyMember: result.already_member,
    });
  }

  return (
    <div className="space-y-5">
      <form className="space-y-3" onSubmit={findLeague}>
        <Label htmlFor="league-code">Codice lega</Label>
        <div className="flex gap-2">
          <Input
            autoCapitalize="characters"
            className="h-12 flex-1 font-mono text-base tracking-[0.16em] uppercase"
            id="league-code"
            maxLength={16}
            onChange={(event) => setCode(event.target.value.toUpperCase())}
            placeholder="K8PJ4D"
            required
            value={code}
          />
          <Button className="size-12" disabled={loading} size="icon-lg" type="submit">
            {loading ? <LoaderCircle className="animate-spin" /> : <Search />}
            <span className="sr-only">Cerca lega</span>
          </Button>
        </div>
      </form>
      {preview ? <JoinLeaguePreview code={code} preview={preview} /> : null}
    </div>
  );
}

export function JoinLeaguePreview({ code, preview }: { code: string; preview: InvitePreview }) {
  const router = useRouter();
  const [joining, setJoining] = useState(false);

  async function joinLeague() {
    if (preview.alreadyMember) {
      router.push(`/leagues/${preview.slug}`);
      return;
    }
    setJoining(true);
    const response = await fetch("/api/leagues/join", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    });
    const result = (await response.json()) as { message?: string; slug?: string };
    setJoining(false);
    if (!response.ok) {
      toast.error(result.message ?? "Ingresso non riuscito.");
      return;
    }
    toast.success(`Benvenuto in ${preview.name}!`);
    router.push(`/leagues/${result.slug ?? preview.slug}`);
    router.refresh();
  }

  const full = preview.memberCount >= preview.maxMembers;
  return (
    <Card className="border-primary/20 bg-primary/4">
      <CardContent>
        <div className="flex items-start gap-4">
          <LeagueLogo className="size-16 rounded-2xl" name={preview.name} url={preview.logoUrl} />
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2"><h2 className="truncate text-lg font-bold">{preview.name}</h2><Badge variant="outline">{preview.footballFormat.replace("v", " vs ")}</Badge></div>
            <p className="mt-2 flex items-center gap-1.5 text-xs text-muted-foreground"><MapPin className="size-3.5" />{preview.city}, {preview.country}</p>
            <p className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground"><UsersRound className="size-3.5" />{preview.memberCount}/{preview.maxMembers} membri</p>
          </div>
        </div>
        {preview.alreadyMember ? <p className="mt-5 flex items-center gap-2 text-sm text-primary"><CheckCircle2 className="size-4" />Fai già parte di questa lega.</p> : null}
        <Button className="mt-5 h-11 w-full rounded-xl font-bold" disabled={joining || full} onClick={joinLeague}>
          {joining ? <LoaderCircle className="animate-spin" /> : null}
          {preview.alreadyMember ? "Apri lega" : full ? "Lega completa" : "Entra nella lega"}
          {!joining && !full ? <ArrowRight /> : null}
        </Button>
      </CardContent>
    </Card>
  );
}
