import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { LeagueForm } from "@/features/leagues/league-form";

export const metadata: Metadata = { title: "Crea lega" };

export default function NewLeaguePage() {
  return (
    <main className="py-6 sm:py-10">
      <Button asChild className="-ms-2" variant="ghost"><Link href="/leagues"><ArrowLeft />Le mie leghe</Link></Button>
      <div className="mx-auto mt-5 max-w-2xl">
        <p className="text-xs font-semibold tracking-[0.18em] text-primary uppercase">Nuova competizione</p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight">Crea la tua lega</h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">Imposta le regole di base. Potrai modificarle in qualsiasi momento.</p>
        <Card className="mt-7"><CardContent><LeagueForm /></CardContent></Card>
      </div>
    </main>
  );
}
