import type { ReactNode } from "react";
import { redirect } from "next/navigation";

import { AppShell } from "@/components/app-shell/app-shell";
import { getManagedLeagues } from "@/features/matches/data";
import type { ManagedLeague } from "@/features/matches/types";
import { getCurrentUser } from "@/lib/auth";
import { hasSupabaseEnv } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { getUnreadNotificationCount } from "@/features/notifications/data";

export default async function LoggedInAppLayout({ children }: { children: ReactNode }) {
  let managedLeagues: ManagedLeague[] = [];
  let userId: string | undefined;
  let unreadNotifications = 0;
  if (hasSupabaseEnv()) {
    const user = await getCurrentUser();
    if (user) {
      userId = user.id;
      const supabase = await createClient();
      const [{ data: profile }, nextManagedLeagues, nextUnreadNotifications] = await Promise.all([
        supabase
          .from("profiles")
          .select("onboarding_completed")
          .eq("id", user.id)
          .maybeSingle(),
        getManagedLeagues(),
        getUnreadNotificationCount(user.id),
      ]);
      if (!profile?.onboarding_completed) redirect("/onboarding");
      managedLeagues = nextManagedLeagues;
      unreadNotifications = nextUnreadNotifications;
    }
  }
  return <AppShell managedLeagues={managedLeagues} unreadNotifications={unreadNotifications} userId={userId}>{children}</AppShell>;
}
