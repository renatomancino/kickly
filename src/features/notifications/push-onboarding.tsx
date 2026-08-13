"use client";

import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { BellRing, Check, Smartphone } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  enablePushOnDevice,
  getDevicePushSubscription,
  isStandaloneApp,
  pushErrorMessage,
  supportsWebPush,
  syncDevicePushSubscription,
} from "./push-client";

const DISMISSED_AT_KEY = "kickly:push-onboarding-dismissed-at";
const REMINDER_DELAY_MS = 7 * 24 * 60 * 60 * 1000;

type OnboardingState = "hidden" | "ready" | "blocked";

export function PushOnboarding() {
  const [state, setState] = useState<OnboardingState>("hidden");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function inspectInstalledApp() {
      if (!isStandaloneApp() || !supportsWebPush()) return;

      try {
        const subscription = await getDevicePushSubscription();
        if (subscription) {
          await syncDevicePushSubscription(subscription);
          return;
        }
      } catch {
        // The onboarding can still explain or retry the setup.
      }

      const dismissedAt = Number(localStorage.getItem(DISMISSED_AT_KEY) ?? 0);
      if (Date.now() - dismissedAt < REMINDER_DELAY_MS || cancelled) return;
      setState(Notification.permission === "denied" ? "blocked" : "ready");
    }

    void inspectInstalledApp();
    return () => {
      cancelled = true;
    };
  }, []);

  function dismiss() {
    localStorage.setItem(DISMISSED_AT_KEY, String(Date.now()));
    setState("hidden");
  }

  async function enableNotifications() {
    setBusy(true);
    try {
      await enablePushOnDevice();
      localStorage.removeItem(DISMISSED_AT_KEY);
      setState("hidden");
      toast.success("Notifiche attivate su questo dispositivo.");
    } catch (error) {
      if (Notification.permission === "denied") setState("blocked");
      toast.error(pushErrorMessage(error));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={state !== "hidden"} onOpenChange={(open) => { if (!open) dismiss(); }}>
      <DialogContent className="overflow-hidden p-0 sm:max-w-md" showCloseButton={false}>
        <div className="bg-gradient-to-br from-primary/25 via-primary/10 to-transparent px-5 pb-5 pt-6">
          <div className="mb-4 flex size-12 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-lg shadow-primary/20">
            <BellRing className="size-6" />
          </div>
          <DialogHeader>
            <DialogTitle className="text-xl">
              {state === "blocked" ? "Riattiva le notifiche" : "Non perderti la prossima partita"}
            </DialogTitle>
            <DialogDescription className="text-sm leading-6">
              {state === "blocked"
                ? "Il permesso è stato bloccato. Apri le impostazioni del browser o del telefono, abilita le notifiche per Kickly e poi torna nell’app."
                : "Attiva gli avvisi per nuovi match, posti liberati e promemoria. Arrivano anche quando Kickly è chiusa."}
            </DialogDescription>
          </DialogHeader>
        </div>

        <div className="space-y-3 px-5">
          <Benefit icon={<Smartphone />} text="Avvisi fuori dall’app" />
          <Benefit icon={<Check />} text="Puoi disattivarli quando vuoi dal profilo" />
        </div>

        <DialogFooter className="mx-0 mb-0 rounded-none px-5 pb-[max(1rem,env(safe-area-inset-bottom))]">
          <Button disabled={busy} onClick={dismiss} variant="ghost">
            {state === "blocked" ? "Ho capito" : "Non ora"}
          </Button>
          {state === "ready" ? (
            <Button disabled={busy} onClick={enableNotifications}>
              {busy ? "Attivazione…" : "Attiva notifiche"}
            </Button>
          ) : null}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Benefit({ icon, text }: { icon: ReactNode; text: string }) {
  return (
    <div className="flex items-center gap-3 text-sm font-medium [&_svg]:size-4 [&_svg]:text-primary">
      <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10">{icon}</span>
      <span>{text}</span>
    </div>
  );
}
