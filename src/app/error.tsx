"use client";

import { useEffect } from "react";
import { AlertTriangle, RotateCcw } from "lucide-react";

import { Button } from "@/components/ui/button";

export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { console.error(error); }, [error]);
  return <main className="grid min-h-dvh place-items-center px-5"><div className="max-w-md text-center"><AlertTriangle className="mx-auto size-10 text-primary" /><h1 className="mt-5 text-2xl font-bold">Qualcosa è andato storto</h1><p className="mt-3 text-sm leading-6 text-muted-foreground">La squadra tecnica è già in campo. Puoi riprovare senza perdere la sessione.</p><Button className="mt-6" onClick={reset}><RotateCcw />Riprova</Button></div></main>;
}
