import type { Metadata } from "next";
import Link from "next/link";
import { Plus, TicketCheck } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { LeagueCard } from "@/features/leagues/league-card";
import { getUserLeagues } from "@/features/leagues/data";

export const metadata: Metadata = { title: "Le mie leghe" };

export default async function LeaguesPage() {
  const leagues = await getUserLeagues();
  return (
    <main className="py-6 sm:py-10">
      <header className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-semibold tracking-[0.18em] text-primary uppercase">Il tuo calcio</p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight">Le mie leghe</h1>
          <p className="mt-2 text-sm text-muted-foreground">Squadre, amici e rivalità: tutto parte da qui.</p>
        </div>
        <div className="grid grid-cols-2 gap-2 sm:flex">
          <Button asChild className="h-11 rounded-xl font-bold"><Link href="/leagues/new"><Plus />Crea lega</Link></Button>
          <Button asChild className="h-11 rounded-xl" variant="outline"><Link href="/leagues/join"><TicketCheck />Entra</Link></Button>
        </div>
      </header>

      {leagues.length ? (
        <div className="mt-8 grid gap-3 md:grid-cols-2">{leagues.map((league) => <LeagueCard key={league.id} league={league} />)}</div>
      ) : (
        <Card className="mt-10 border-dashed">
          <CardContent className="py-12 text-center">
            <div className="mx-auto grid size-14 place-items-center rounded-2xl bg-primary/10 text-primary"><Plus className="size-6" /></div>
            <h2 className="mt-5 text-xl font-bold">La tua prima lega ti aspetta</h2>
            <p className="mx-auto mt-2 max-w-sm text-sm leading-6 text-muted-foreground">Creane una per organizzare il tuo gruppo oppure entra con il codice che ti hanno condiviso.</p>
            <div className="mx-auto mt-6 flex max-w-sm flex-col gap-2 sm:flex-row sm:justify-center"><Button asChild><Link href="/leagues/new">Crea la tua prima lega</Link></Button><Button asChild variant="outline"><Link href="/leagues/join">Entra con un codice</Link></Button></div>
          </CardContent>
        </Card>
      )}
    </main>
  );
}
