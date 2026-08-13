import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { JoinLeagueSearch } from "@/features/leagues/join-league";

export const metadata: Metadata = { title: "Entra in una lega" };

export default function JoinLeaguePage() {
  return (
    <main className="py-6 sm:py-10">
      <Button asChild className="-ms-2" variant="ghost"><Link href="/leagues"><ArrowLeft />Le mie leghe</Link></Button>
      <div className="mx-auto mt-8 max-w-lg">
        <p className="text-xs font-semibold tracking-[0.18em] text-primary uppercase">Hai ricevuto un invito?</p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight">Entra in una lega</h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">Inserisci il codice condiviso dall’admin per vedere la lega e unirti al gruppo.</p>
        <Card className="mt-7"><CardContent><JoinLeagueSearch /></CardContent></Card>
      </div>
    </main>
  );
}
