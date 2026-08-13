import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { getPlayerProfile } from "@/features/profile/data";
import { PlayerProfileView } from "@/features/profile/player-profile-view";

export async function generateMetadata({ params }: { params: Promise<{ username: string }> }): Promise<Metadata> { const { username } = await params; return { title: `@${username}` }; }
export default async function PlayerPage({ params }: { params: Promise<{ username: string }> }) { const { username } = await params; const data = await getPlayerProfile(username); if (!data) notFound(); return <PlayerProfileView data={data} />; }
