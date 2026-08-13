import { Skeleton } from "@/components/ui/skeleton";

export default function LeaguesLoading() {
  return <main className="py-8"><Skeleton className="h-8 w-48" /><Skeleton className="mt-3 h-4 w-72" /><div className="mt-8 grid gap-3 md:grid-cols-2">{Array.from({ length: 4 }).map((_, index) => <Skeleton className="h-28 rounded-xl" key={index} />)}</div></main>;
}
