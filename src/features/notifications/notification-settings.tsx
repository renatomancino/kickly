"use client";

import { useState } from "react";
import { BellRing, Smartphone } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { NotificationPreferences } from "./types";

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
    const next = { ...prefs, [key]: !prefs[key] };
    setPrefs(next); setBusy(true);
    const { push_enabled: _push, ...payload } = next;
    const response = await fetch("/api/notification-preferences", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    setBusy(false);
    if (!response.ok) { setPrefs(prefs); toast.error("Preferenza non salvata."); }
  }
  return <Card><CardHeader><CardTitle className="flex items-center gap-2"><BellRing className="size-5 text-primary"/>Notifiche</CardTitle></CardHeader><CardContent className="space-y-1">{choices.map((choice) => <label className="flex cursor-pointer items-center gap-3 rounded-xl px-2 py-3 hover:bg-muted/30" key={choice.key}><span className="min-w-0 flex-1"><span className="block font-semibold">{choice.label}</span><span className="block text-xs text-muted-foreground">{choice.description}</span></span><input checked={prefs[choice.key]} className="size-5 accent-primary" disabled={busy} onChange={() => toggle(choice.key)} type="checkbox" /></label>)}</CardContent></Card>;
}

export function PushSettings({ initiallyEnabled }: { initiallyEnabled: boolean }) {
  const [enabled, setEnabled] = useState(initiallyEnabled);
  const [busy, setBusy] = useState(false);
  const supported = typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
  async function togglePush() {
    setBusy(true);
    try {
      const registration = await navigator.serviceWorker.register("/sw.js");
      if (enabled) {
        const existing = await registration.pushManager.getSubscription();
        if (existing) {
          await fetch("/api/push/subscribe", { method: "DELETE", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ endpoint: existing.endpoint }) });
          await existing.unsubscribe();
        }
        setEnabled(false); toast.success("Notifiche push disattivate."); return;
      }
      const permission = await Notification.requestPermission();
      if (permission !== "granted") throw new Error("permission");
      const keyResponse = await fetch("/api/push/public-key");
      if (!keyResponse.ok) throw new Error("config");
      const { key } = await keyResponse.json() as { key: string };
      const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: urlBase64ToUint8Array(key) as BufferSource });
      const json = subscription.toJSON();
      const response = await fetch("/api/push/subscribe", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ endpoint: subscription.endpoint, keys: json.keys, deviceName: deviceLabel() }) });
      if (!response.ok) { await subscription.unsubscribe(); throw new Error("save"); }
      setEnabled(true); toast.success("Notifiche push attivate.");
    } catch (error) {
      toast.error(error instanceof Error && error.message === "permission" ? "Permesso notifiche non concesso." : "Attivazione push non riuscita.");
    } finally { setBusy(false); }
  }
  return <Card><CardHeader><CardTitle className="flex items-center gap-2"><Smartphone className="size-5 text-primary"/>Push sul dispositivo</CardTitle></CardHeader><CardContent><div className="flex items-center justify-between gap-4"><div><p className="font-semibold">{enabled ? "Attive" : "Non attive"}</p><p className="mt-1 text-xs text-muted-foreground">Ricevi gli avvisi importanti anche quando Kickly è chiusa.</p></div><Button disabled={!supported || busy} onClick={togglePush} variant={enabled ? "outline" : "default"}>{busy ? "Attendi…" : enabled ? "Disattiva" : "Attiva push"}</Button></div>{!supported ? <p className="mt-3 text-xs text-amber-300">Il browser non supporta le notifiche push.</p> : null}</CardContent></Card>;
}

function urlBase64ToUint8Array(base64: string) { const padding = "=".repeat((4 - base64.length % 4) % 4); const raw = atob((base64 + padding).replace(/-/g, "+").replace(/_/g, "/")); return Uint8Array.from([...raw].map((char) => char.charCodeAt(0))); }
function deviceLabel() { if (/iphone|ipad|ipod/i.test(navigator.userAgent)) return "iPhone/iPad"; if (/android/i.test(navigator.userAgent)) return "Android"; return "Browser desktop"; }
