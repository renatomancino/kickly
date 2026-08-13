import Link from "next/link";

import { Button } from "@/components/ui/button";

export default function NotFound() {
  return <main className="grid min-h-dvh place-items-center px-5 text-center"><div><p className="text-7xl font-black text-primary">404</p><h1 className="mt-3 text-2xl font-bold">Fuori dal campo</h1><p className="mt-2 text-sm text-muted-foreground">Questa pagina non esiste o non è più disponibile.</p><Button asChild className="mt-6"><Link href="/">Torna alla home</Link></Button></div></main>;
}
