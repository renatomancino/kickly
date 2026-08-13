import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";

import { getMatchById } from "@/features/matches/data";
import { PostGameManager } from "@/features/matches/post-game-manager";

export const metadata: Metadata = { title: "Gestisci risultato" };

export default async function ManageResultPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const match = await getMatchById(id);
  if (!match) notFound();
  if (match.currentUserRole !== "owner" && match.currentUserRole !== "admin") redirect(`/matches/${id}`);
  return <PostGameManager match={match} />;
}
