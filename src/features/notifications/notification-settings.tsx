"use client";

import { useEffect, useState } from "react";
import { BellRing, Smartphone } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { NotificationPreferences } from "./types";
import {
  disablePushOnDevice,
  enablePushOnDevice,
  getDevicePushSubscription,
  isIosDevice,
  isStandaloneApp,
  pushErrorMessage,
  supportsWebPush,
  syncDevicePushSubscription,
} from "./push-client";

const choices: { key: keyof Omit<NotificationPreferences, "push_enabled">; label: string; description: string }[] = [
  { key: "match_created", label: "Nuove partite", description: "Quando viene pubblicata una partita." },
  { key: "match_updates", label: "Aggiornamenti partite", description: "Modifiche importanti e cancellazioni." },
  { key: "match_reminders", label: "Promemoria", description: "Prima delle partite e della chiusura voto MVP." },
  { key: "waitlist", label: "Lista d’attesa", description: "Quando si libera un posto per te." },
  { key: "mvp", label: "MVP", description: "Apertura votazioni e vincitore." },
  { key: "rating", label: "Overall", description: "Quando cambia il tuo rating." },
  { key: "league_updates", label: "Lega e ruoli", description: "Inviti e modifiche al tuo ruolo." },
];

export function NotificationSettings({ initial }: { initial: NotificationPreferences }) {
  const [prefs, setPrefs] = useState(initial);
  const [busy, setBusy] = useState(false);
  async function toggle(key: (typeof choices)[number]["key"]) {
    const previous = prefs;
    const next = { ...prefs, [key]: !prefs[key] };
    setPrefs(next);
    setBusy(true);
    try {
      const { push_enabled: _push, ...payload } = next;
      const response = await fetch("/api/notification-preferences", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
      if (!response.ok) throw new Error("save");
    } catch {
      setPrefs(previous);
      toast.error("Preferenza non salvata.");
    } finally {
      setBusy(false);
    }
  }
  return <Card><CardHeader><CardTitle className="flex items-center gap-2"><BellRing className="size-5 text-primary"/>Notifiche</CardTitle></CardHeader><CardContent className="space-y-1">{choices.map((choice) => <label className="flex cursor-pointer items-center gap-3 rounded-xl px-2 py-3 hover:bg-muted/30" key={choice.key}><span className="min-w-0 flex-1"><span className="block font-semibold">{choice.label}</span><span className="block text-xs text-muted-foreground">{choice.description}</span></span><input checked={prefs[choice.key]} className="size-5 accent-primary" disabled={busy} onChange={() => toggle(choice.key)} type="checkbox" /></label>)}</CardContent></Card>;
}

export function PushSettings({ initiallyEnabled }: { initiallyEnabled: boolean }) {
  const [enabled, setEnabled] = useState(initiallyEnabled);
  const [busy, setBusy] = useState(false);
  const [supported, setSupported] = useState<boolean | null>(null);
  const [needsIosInstall, setNeedsIosInstall] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function reconcileDeviceState() {
      const available = supportsWebPush();
      const iosInstallRequired = isIosDevice() && !isStandaloneApp();
      let hasSubscription = false;
      if (available) {
        try {
          const subscription = await getDevicePushSubscription();
          if (subscription) await syncDevicePushSubscription(subscription);
          hasSubscription = Boolean(subscription);
        } catch {
          hasSubscription = false;
        }
      }
      if (cancelled) return;
      setSupported(available);
      setNeedsIosInstall(iosInstallRequired);
      setEnabled(hasSubscription);
    }

    void reconcileDeviceState();

    return () => {
      cancelled = true;
    };
  }, []);

  async function togglePush() {
    setBusy(true);
    try {
      if (enabled) {
        await disablePushOnDevice();
        setEnabled(false);
        toast.success("Notifiche push disattivate su questo dispositivo.");
        return;
      }
      await enablePushOnDevice();
      setEnabled(true);
      toast.success("Notifiche push attivate su questo dispositivo.");
    } catch (error) {
      toast.error(pushErrorMessage(error));
    } finally {
      setBusy(false);
    }
  }
  return <Card><CardHeader><CardTitle className="flex items-center gap-2"><Smartphone className="size-5 text-primary"/>Push sul dispositivo</CardTitle></CardHeader><CardContent><div className="flex flex-col items-stretch gap-4 sm:flex-row sm:items-center sm:justify-between"><div><p className="font-semibold">{supported === null ? "Verifica in corso…" : enabled ? "Attive su questo dispositivo" : "Non attive su questo dispositivo"}</p><p className="mt-1 text-xs text-muted-foreground">Ricevi gli avvisi importanti anche quando Kickly è chiusa.</p></div><Button disabled={supported !== true || busy || needsIosInstall} onClick={togglePush} variant={enabled ? "outline" : "default"}>{busy ? "Attendi…" : enabled ? "Disattiva" : "Attiva push"}</Button></div>{supported === false ? <p className="mt-3 text-xs text-amber-300">Il browser non supporta le notifiche push.</p> : null}{needsIosInstall ? <p className="mt-3 text-xs leading-5 text-amber-300">Su iPhone, aggiungi prima Kickly alla schermata Home e aprila dall’icona installata.</p> : null}</CardContent></Card>;
}
