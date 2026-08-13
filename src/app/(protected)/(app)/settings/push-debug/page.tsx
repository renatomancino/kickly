"use client";

import { useCallback, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { BellRing, CheckCircle2, CircleAlert, RefreshCw, Send, Smartphone } from "lucide-react";

import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  enablePushOnDevice,
  isStandaloneApp,
  pushErrorMessage,
  supportsWebPush,
} from "@/features/notifications/push-client";

interface DiagnosticState {
  pwaStandalone: boolean;
  serviceWorkerSupported: boolean;
  serviceWorkerActive: boolean;
  serviceWorkerControlling: boolean;
  notificationPermission: NotificationPermission | null;
  pushManagerSupported: boolean;
  subscriptionPresent: boolean;
  subscriptionInDatabase: boolean;
  lastAttemptTime: string | null;
  lastDeliveryStatus: string | null;
  sanitizedError: string | null;
  loading: boolean;
}

interface DeliveryStatus {
  delivery_status?: string;
  delivery_count?: number;
  sent_count?: number;
  failed_count?: number;
  dead_count?: number;
}

const initialDiagnostics: DiagnosticState = {
  pwaStandalone: false,
  serviceWorkerSupported: false,
  serviceWorkerActive: false,
  serviceWorkerControlling: false,
  notificationPermission: null,
  pushManagerSupported: false,
  subscriptionPresent: false,
  subscriptionInDatabase: false,
  lastAttemptTime: null,
  lastDeliveryStatus: null,
  sanitizedError: null,
  loading: true,
};

export default function PushDebugPage() {
  const [diagnostics, setDiagnostics] = useState(initialDiagnostics);
  const [testPushLoading, setTestPushLoading] = useState(false);
  const [testPushMessage, setTestPushMessage] = useState<string | null>(null);
  const [testPushSucceeded, setTestPushSucceeded] = useState(false);

  const runDiagnostics = useCallback(async () => {
    setDiagnostics((current) => ({ ...current, loading: true, sanitizedError: null }));
    try {
      const standalone = isStandaloneApp();
      const serviceWorkerSupported = "serviceWorker" in navigator;
      const pushManagerSupported = supportsWebPush();
      let serviceWorkerActive = false;
      let serviceWorkerControlling = false;
      let subscriptionPresent = false;

      if (serviceWorkerSupported) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        serviceWorkerActive = registrations.some((registration) => Boolean(registration.active));
        serviceWorkerControlling = navigator.serviceWorker.controller !== null;
        if (pushManagerSupported) {
          const registration = await navigator.serviceWorker.ready;
          subscriptionPresent = Boolean(await registration.pushManager.getSubscription());
        }
      }

      const accountResponse = await fetch("/api/notifications/push-subscription", { cache: "no-store" });
      const accountData = accountResponse.ok
        ? await accountResponse.json() as { subscription?: unknown }
        : { subscription: null };

      setDiagnostics((current) => ({
        ...current,
        pwaStandalone: standalone,
        serviceWorkerSupported,
        serviceWorkerActive,
        serviceWorkerControlling,
        notificationPermission: "Notification" in window ? Notification.permission : null,
        pushManagerSupported,
        subscriptionPresent,
        subscriptionInDatabase: Boolean(accountData.subscription),
        lastAttemptTime: new Date().toISOString(),
        sanitizedError: null,
        loading: false,
      }));
    } catch {
      setDiagnostics((current) => ({
        ...current,
        sanitizedError: "Non sono riuscito a completare la diagnosi.",
        loading: false,
      }));
    }
  }, []);

  useEffect(() => {
    void runDiagnostics();
  }, [runDiagnostics]);

  async function handleEnableNotifications() {
    try {
      await enablePushOnDevice();
      await runDiagnostics();
      setDiagnostics((current) => ({ ...current, sanitizedError: null }));
    } catch (error) {
      setDiagnostics((current) => ({ ...current, sanitizedError: pushErrorMessage(error) }));
    }
  }

  async function handleSendTestPush() {
    setTestPushLoading(true);
    setTestPushMessage(null);
    setTestPushSucceeded(false);

    try {
      const response = await fetch("/api/notifications/send-test-push", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: "Test Kickly: città e attività",
          body: "Perché Kickly è pronta: accenti ed emoji funzionano ⚽",
          url: "/settings/push-debug?test=success",
        }),
      });
      const data = await response.json() as { error?: string; notificationId?: string; status?: string };
      if (!response.ok || !data.notificationId) throw new Error(friendlyTestError(data.error));

      setTestPushMessage("Notifica in coda: puoi chiudere o minimizzare Kickly mentre aspetti.");
      setDiagnostics((current) => ({
        ...current,
        lastAttemptTime: new Date().toISOString(),
        lastDeliveryStatus: data.status ?? "QUEUED_FOR_PROVIDER",
      }));

      const delivery = await pollDelivery(data.notificationId);
      const deliveryStatus = delivery.delivery_status ?? "QUEUED";
      setDiagnostics((current) => ({ ...current, lastDeliveryStatus: deliveryStatus }));

      if (deliveryStatus === "SENT") {
        setTestPushSucceeded(true);
        setTestPushMessage("Il provider ha accettato la notifica. Verifica che il popup sia apparso anche con Kickly chiusa.");
      } else if (deliveryStatus === "DEAD") {
        throw new Error("La sottoscrizione non è più valida. Riattiva le notifiche sul telefono.");
      } else {
        setTestPushMessage("La consegna è ancora in elaborazione. Il worker riproverà automaticamente.");
      }
    } catch (error) {
      setTestPushMessage(error instanceof Error ? error.message : "Test push non riuscito.");
      setTestPushSucceeded(false);
    } finally {
      setTestPushLoading(false);
    }
  }

  const currentDeviceReady = diagnostics.notificationPermission === "granted" && diagnostics.subscriptionPresent;
  const accountReady = diagnostics.subscriptionInDatabase;

  return (
    <div className="mx-auto w-full max-w-3xl space-y-4 py-5 sm:space-y-6 sm:py-8">
      <header className="flex items-start gap-3">
        <span className="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-primary/15 text-primary">
          <BellRing className="size-5" />
        </span>
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Test notifiche push</h1>
          <p className="mt-1 text-sm leading-5 text-muted-foreground">
            Controlla il dispositivo e prova una notifica reale fuori dall’app.
          </p>
        </div>
      </header>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <StatusCard
          icon={<Smartphone />}
          label="Questo dispositivo"
          ready={currentDeviceReady}
          value={currentDeviceReady ? "Pronto" : permissionLabel(diagnostics.notificationPermission)}
        />
        <StatusCard
          icon={<BellRing />}
          label="Account Kickly"
          ready={accountReady}
          value={accountReady ? "Almeno un dispositivo attivo" : "Nessun dispositivo attivo"}
        />
      </div>

      {diagnostics.sanitizedError ? (
        <Alert variant="destructive">
          <CircleAlert />
          <AlertDescription>{diagnostics.sanitizedError}</AlertDescription>
        </Alert>
      ) : null}

      {testPushMessage ? (
        <Alert variant={testPushSucceeded ? "default" : "destructive"}>
          {testPushSucceeded ? <CheckCircle2 /> : <CircleAlert />}
          <AlertDescription>{testPushMessage}</AlertDescription>
        </Alert>
      ) : null}

      <Card className="overflow-hidden">
        <CardHeader>
          <CardTitle>Prova fuori dall’app</CardTitle>
          <CardDescription>
            Premi invia, poi passa alla Home del telefono o blocca lo schermo. Il test usa lo stesso worker delle notifiche reali.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Button className="h-12 w-full text-base" disabled={testPushLoading || !accountReady} onClick={handleSendTestPush}>
            {testPushLoading ? <RefreshCw className="animate-spin" /> : <Send />}
            {testPushLoading ? "Verifica consegna…" : "Invia notifica di prova"}
          </Button>
          {!accountReady ? (
            <p className="text-center text-xs leading-5 text-amber-300">
              Prima attiva le notifiche su almeno un telefono o browser.
            </p>
          ) : null}
          <Button className="w-full" onClick={handleEnableNotifications} variant="outline">
            Attiva su questo dispositivo
          </Button>
        </CardContent>
      </Card>

      <details className="group rounded-2xl border bg-card px-4 py-3">
        <summary className="flex cursor-pointer list-none items-center justify-between text-sm font-semibold">
          Diagnostica tecnica
          <Badge variant="outline">{diagnostics.loading ? "Verifica…" : "Aggiornata"}</Badge>
        </summary>
        <div className="mt-4 space-y-1 border-t pt-3">
          <DiagnosticRow label="App installata" value={yesNo(diagnostics.pwaStandalone)} good={diagnostics.pwaStandalone} />
          <DiagnosticRow label="Service worker" value={yesNo(diagnostics.serviceWorkerActive)} good={diagnostics.serviceWorkerActive} />
          <DiagnosticRow label="Pagina controllata" value={yesNo(diagnostics.serviceWorkerControlling)} good={diagnostics.serviceWorkerControlling} />
          <DiagnosticRow label="Push supportate" value={yesNo(diagnostics.pushManagerSupported)} good={diagnostics.pushManagerSupported} />
          <DiagnosticRow label="Permesso" value={permissionLabel(diagnostics.notificationPermission)} good={diagnostics.notificationPermission === "granted"} />
          <DiagnosticRow label="Sottoscrizione locale" value={yesNo(diagnostics.subscriptionPresent)} good={diagnostics.subscriptionPresent} />
          {diagnostics.lastDeliveryStatus ? <DiagnosticRow label="Ultima consegna" value={diagnostics.lastDeliveryStatus} /> : null}
          <Button className="mt-3 w-full" disabled={diagnostics.loading} onClick={runDiagnostics} size="sm" variant="ghost">
            <RefreshCw className={diagnostics.loading ? "animate-spin" : ""} /> Aggiorna controllo
          </Button>
        </div>
      </details>
    </div>
  );
}

function StatusCard({ icon, label, ready, value }: { icon: ReactNode; label: string; ready: boolean; value: string }) {
  return (
    <Card>
      <CardContent className="flex items-center gap-3 p-4">
        <span className={`flex size-10 shrink-0 items-center justify-center rounded-xl [&_svg]:size-5 ${ready ? "bg-emerald-500/15 text-emerald-400" : "bg-amber-500/15 text-amber-300"}`}>
          {icon}
        </span>
        <div className="min-w-0">
          <p className="text-xs font-medium text-muted-foreground">{label}</p>
          <p className="truncate text-sm font-semibold">{value}</p>
        </div>
      </CardContent>
    </Card>
  );
}

function DiagnosticRow({ label, value, good }: { label: string; value: string; good?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b py-2.5 last:border-0">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className={`text-right text-sm font-semibold ${good === false ? "text-amber-300" : good ? "text-emerald-400" : ""}`}>{value}</span>
    </div>
  );
}

async function pollDelivery(notificationId: string) {
  let latest: DeliveryStatus = { delivery_status: "QUEUED" };
  for (let attempt = 0; attempt < 8; attempt += 1) {
    await new Promise((resolve) => window.setTimeout(resolve, 1_250));
    const response = await fetch(`/api/notifications/send-test-push?notificationId=${encodeURIComponent(notificationId)}`, { cache: "no-store" });
    if (!response.ok) continue;
    latest = await response.json() as DeliveryStatus;
    if (["SENT", "DEAD"].includes(latest.delivery_status ?? "")) break;
  }
  return latest;
}

function permissionLabel(permission: NotificationPermission | null) {
  if (permission === "granted") return "Permesso concesso";
  if (permission === "denied") return "Permesso bloccato";
  if (permission === "default") return "Da attivare";
  return "Non disponibile";
}

function friendlyTestError(error?: string) {
  if (error === "NO_ACTIVE_PUSH_SUBSCRIPTION") return "Nessun dispositivo ha le notifiche attive.";
  if (error === "TEST_PUSH_RATE_LIMITED") return "Attendi qualche secondo prima di inviare un altro test.";
  return "Non sono riuscito a mettere in coda la notifica.";
}

function yesNo(value: boolean) {
  return value ? "Sì" : "No";
}
