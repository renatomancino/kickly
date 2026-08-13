"use client";

import { useEffect, useState } from "react";
import { Download, Share } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

interface InstallPromptEvent extends Event { prompt: () => Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> }

export function PwaRuntime() {
  const [prompt, setPrompt] = useState<InstallPromptEvent | null>(null);
  const [ios, setIos] = useState(false);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (window.matchMedia("(display-mode: standalone)").matches || localStorage.getItem("kickly-install-dismissed")) return;
    const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
    if (isIos) { queueMicrotask(() => { setIos(true); setVisible(true); }); }
    const handler = (event: Event) => { event.preventDefault(); setPrompt(event as InstallPromptEvent); setVisible(true); };
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);
  if (!visible) return null;
  function dismiss() { localStorage.setItem("kickly-install-dismissed", "1"); setVisible(false); }
  async function install() { if (!prompt) return; await prompt.prompt(); if ((await prompt.userChoice).outcome === "accepted") setVisible(false); }
  return <div className="fixed inset-x-4 bottom-20 z-40 mx-auto max-w-md md:bottom-5"><Card className="border-primary/20 bg-card/95 shadow-2xl backdrop-blur"><CardContent className="flex items-center gap-3"><span className="grid size-10 shrink-0 place-items-center rounded-xl bg-primary/12 text-primary">{ios ? <Share className="size-5" /> : <Download className="size-5" />}</span><div className="min-w-0 flex-1"><p className="font-bold">Installa Kickly</p><p className="text-xs text-muted-foreground">{ios ? "Apri Condividi e scegli Aggiungi alla schermata Home." : "Accesso rapido e notifiche come un’app."}</p></div>{!ios ? <Button onClick={install} size="sm">Installa</Button> : null}<button className="px-1 text-lg text-muted-foreground" onClick={dismiss} type="button" aria-label="Chiudi">×</button></CardContent></Card></div>;
}
