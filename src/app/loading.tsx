import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return <main className="mx-auto min-h-dvh max-w-6xl px-4 py-8"><div className="flex items-center gap-3"><Skeleton className="size-10 rounded-xl" /><Skeleton className="h-5 w-32" /></div><Skeleton className="mt-10 h-64 w-full rounded-2xl" /><div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">{Array.from({ length: 4 }).map((_, index) => <Skeleton className="h-28 rounded-xl" key={index} />)}</div></main>;
}
