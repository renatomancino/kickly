import { Skeleton } from "@/components/ui/skeleton";

export default function MatchesLoading() {
  return <main className="py-8"><Skeleton className="h-10 w-44" /><Skeleton className="mt-3 h-5 w-72" /><div className="mt-8 grid gap-3 lg:grid-cols-2">{Array.from({ length: 4 }, (_, index) => <Skeleton className="h-32 rounded-2xl" key={index} />)}</div></main>;
}
