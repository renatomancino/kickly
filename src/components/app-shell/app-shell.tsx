import type { ReactNode } from "react";
import Link from "next/link";
import { CalendarDays, Home, Shield, UserRound } from "lucide-react";

import { BrandMark } from "@/components/brand-mark";
import { BottomNav } from "./bottom-nav";
import type { ManagedLeague } from "@/features/matches/types";
import { NotificationBell } from "@/features/notifications/notification-bell";
import { NotificationRuntime } from "@/features/notifications/notification-runtime";
import { PushOnboarding } from "@/features/notifications/push-onboarding";
import { PwaRuntime } from "@/components/pwa/pwa-runtime";

export function AppShell({ children, managedLeagues, userId, unreadNotifications }: { children: ReactNode; managedLeagues: ManagedLeague[]; userId?: string; unreadNotifications: number }) {
  return (
    <div className="min-h-dvh bg-background pb-24 md:pb-8">
      <header className="hidden border-b bg-background/85 backdrop-blur-xl md:block"><div className="mx-auto flex h-16 max-w-6xl items-center gap-8 px-6"><Link className="me-auto flex items-center gap-2 font-bold" href="/dashboard"><BrandMark className="size-8" />Kickly</Link><DesktopLink href="/dashboard" icon={<Home />}>Home</DesktopLink><DesktopLink href="/matches" icon={<CalendarDays />}>Partite</DesktopLink><DesktopLink href="/leagues" icon={<Shield />}>Leghe</DesktopLink><DesktopLink href="/profile" icon={<UserRound />}>Profilo</DesktopLink><NotificationBell unread={unreadNotifications} /></div></header>
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6">{children}</div>
      <BottomNav managedLeagues={managedLeagues} />
      {userId ? <NotificationRuntime unread={unreadNotifications} userId={userId} /> : null}
      {userId ? <PushOnboarding /> : null}
      <PwaRuntime />
    </div>
  );
}

function DesktopLink({ href, icon, children }: { href: string; icon: ReactNode; children: ReactNode }) {
  return <Link className="flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground [&_svg]:size-4" href={href}>{icon}{children}</Link>;
}
