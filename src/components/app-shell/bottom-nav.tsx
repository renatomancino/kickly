"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { CalendarDays, Home, Plus, Shield, UserRound } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { cn } from "@/lib/utils";
import type { ManagedLeague } from "@/features/matches/types";

const items = [
  { label: "Home", href: "/dashboard", icon: Home },
  { label: "Partite", href: "/matches", icon: CalendarDays },
  { label: "Leghe", href: "/leagues", icon: Shield },
  { label: "Profilo", href: "/profile", icon: UserRound },
];

export function BottomNav({ managedLeagues }: { managedLeagues: ManagedLeague[] }) {
  const pathname = usePathname();
  const createMatchHref = managedLeagues.length === 1 ? `/matches/new?league=${managedLeagues[0].id}` : "/matches/new";
  return (
    <nav aria-label="Navigazione principale" className="fixed inset-x-0 bottom-0 z-50 border-t bg-background/95 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl md:hidden">
      <div className="mx-auto grid h-16 max-w-lg grid-cols-5 items-center px-2">
        {items.slice(0, 2).map((item) => <NavItem key={item.label} active={isActive(pathname, item.href)} {...item} />)}
        <Sheet>
          <SheetTrigger asChild><button aria-label="Apri azioni rapide" className="mx-auto grid size-12 -translate-y-3 place-items-center rounded-2xl bg-primary text-primary-foreground shadow-[0_10px_28px_-8px_var(--primary)]" type="button"><Plus className="size-6" /></button></SheetTrigger>
          <SheetContent className="rounded-t-3xl" side="bottom"><SheetHeader><SheetTitle>Azioni rapide</SheetTitle><SheetDescription>Cosa vuoi organizzare?</SheetDescription></SheetHeader><div className="grid gap-3 px-4 pb-8">{managedLeagues.length ? <Button asChild className="h-12 rounded-xl font-bold"><Link href={createMatchHref}><CalendarDays />Crea partita</Link></Button> : <Button className="h-12 rounded-xl" disabled><CalendarDays />Crea partita</Button>}<Button asChild className="h-12 rounded-xl" variant="outline"><Link href="/leagues/new"><Shield />Crea lega</Link></Button></div></SheetContent>
        </Sheet>
        {items.slice(2).map((item) => <NavItem key={item.label} active={isActive(pathname, item.href)} {...item} />)}
      </div>
    </nav>
  );
}

function isActive(pathname: string, href: string) {
  const path = href.split("#")[0];
  return pathname === path || (path !== "/dashboard" && pathname.startsWith(`${path}/`));
}

function NavItem({ label, href, icon: Icon, active }: (typeof items)[number] & { active: boolean }) {
  return (
    <Link aria-current={active ? "page" : undefined} className={cn("flex h-full flex-col items-center justify-center gap-1 text-[10px] font-medium text-muted-foreground transition-colors hover:text-foreground", active && "text-primary")} href={href}>
      <Icon className="size-5" />
      {label}
    </Link>
  );
}
