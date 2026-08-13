import type { Metadata } from "next";

import { DashboardView } from "@/features/dashboard/dashboard-view";
import { getDashboardData } from "@/features/dashboard/data";
import { getCurrentUser } from "@/lib/auth";

export const metadata: Metadata = { title: "Home" };

export default async function DashboardPage() {
  const user = await getCurrentUser();
  const data = await getDashboardData(user?.id);
  return <DashboardView data={data} />;
}
