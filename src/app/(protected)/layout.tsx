import type { Metadata } from "next";
import type { ReactNode } from "react";

import { requireUser } from "@/lib/auth";
import { hasSupabaseEnv } from "@/lib/env";

export const metadata: Metadata = { robots: { index: false, follow: false } };

export default async function ProtectedLayout({ children }: { children: ReactNode }) {
  if (hasSupabaseEnv()) await requireUser();
  return children;
}
