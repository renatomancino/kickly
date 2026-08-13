'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';

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

export default function PushDebugPage() {
  const [diagnostics, setDiagnostics] = useState<DiagnosticState>({
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
  });

  const [testPushLoading, setTestPushLoading] = useState(false);
  const [testPushMessage, setTestPushMessage] = useState<string | null>(null);

  // Run diagnostics on mount
  useEffect(() => {
    async function runDiagnostics() {
      try {
        // Check PWA standalone
        const isStandalone =
          window.matchMedia('(display-mode: standalone)').matches ||
          (window.navigator as any).standalone === true;

        // Check Service Worker
        const swSupported = 'serviceWorker' in navigator;
        let swActive = false;
        let swControlling = false;

        if (swSupported) {
          try {
            const registrations = await navigator.serviceWorker.getRegistrations();
            swActive = registrations.length > 0;
            swControlling = navigator.serviceWorker.controller !== null;
          } catch (err) {
            console.error('Error checking service workers:', err);
          }
        }

        // Check Push Manager
        const pushSupported = swSupported && 'PushManager' in window;

        // Check Notification permission
        const permission = Notification.permission;

        // Check current subscription
        let subscriptionPresent = false;
        if (swSupported && pushSupported) {
          try {
            const registration = await navigator.serviceWorker.ready;
            const subscription = await registration.pushManager.getSubscription();
            subscriptionPresent = subscription !== null;
          } catch (err) {
            console.error('Error checking subscription:', err);
          }
        }

        // Check database subscription
        let subscriptionInDatabase = false;
        let lastDeliveryStatus = null;
        try {
          const response = await fetch('/api/notifications/push-subscription');
          if (response.ok) {
            const data = await response.json();
            subscriptionInDatabase = !!data.subscription;
            lastDeliveryStatus = data.lastDeliveryStatus || null;
          }
        } catch (err) {
          console.error('Error checking database subscription:', err);
        }

        setDiagnostics({
          pwaStandalone: isStandalone,
          serviceWorkerSupported: swSupported,
          serviceWorkerActive: swActive,
          serviceWorkerControlling: swControlling,
          notificationPermission: permission,
          pushManagerSupported: pushSupported,
          subscriptionPresent: subscriptionPresent,
          subscriptionInDatabase: subscriptionInDatabase,
          lastAttemptTime: new Date().toISOString(),
          lastDeliveryStatus: lastDeliveryStatus,
          sanitizedError: null,
          loading: false,
        });
      } catch (err) {
        setDiagnostics((prev) => ({
          ...prev,
          sanitizedError: 'Errore durante la diagnosi',
          loading: false,
        }));
      }
    }

    runDiagnostics();
  }, []);

  // Enable notifications
  async function handleEnableNotifications() {
    try {
      const permission = await Notification.requestPermission();
      setDiagnostics((prev) => ({
        ...prev,
        notificationPermission: permission,
      }));

      if (permission === 'granted') {
        // Try to subscribe
        await handleRecreateSubscription();
      }
    } catch (err) {
      setDiagnostics((prev) => ({
        ...prev,
        sanitizedError: 'Errore nell\'abilitazione delle notifiche',
      }));
    }
  }

  // Recreate subscription
  async function handleRecreateSubscription() {
    try {
      const registration = await navigator.serviceWorker.ready;
      const publicKeyResponse = await fetch('/api/notifications/vapid-public-key');
      const { publicKey: publicKeyBase64 } = await publicKeyResponse.json();
      
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: publicKeyBase64,
      });

      // Save to database
      const response = await fetch('/api/notifications/push-subscription', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subscription: subscription.toJSON() }),
      });

      if (response.ok) {
        setDiagnostics((prev) => ({
          ...prev,
          subscriptionPresent: true,
          subscriptionInDatabase: true,
          sanitizedError: null,
        }));
      } else {
        setDiagnostics((prev) => ({
          ...prev,
          sanitizedError: 'Errore nel salvataggio della subscription',
        }));
      }
    } catch (err) {
      console.error('Error recreating subscription:', err);
      setDiagnostics((prev) => ({
        ...prev,
        sanitizedError: 'Errore nella ricreazione della subscription',
      }));
    }
  }

  // Send test push
  async function handleSendTestPush() {
    setTestPushLoading(true);
    setTestPushMessage(null);

    try {
      const response = await fetch('/api/notifications/send-test-push', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: 'Test notifiche Kickly',
          body: 'Se leggi questo messaggio, le notifiche push funzionano.',
          url: '/settings/push-debug?test=success',
        }),
      });

      const data = await response.json();

      if (response.ok) {
        setTestPushMessage(
          `✓ Test inviato. Stato: ${data.status}. Attendi la notifica sull'iPhone.`
        );
        setDiagnostics((prev) => ({
          ...prev,
          lastAttemptTime: new Date().toISOString(),
          lastDeliveryStatus: data.status,
        }));
      } else {
        setTestPushMessage(
          `✗ Errore: ${data.error || 'Errore sconosciuto'}`
        );
      }
    } catch (err) {
      console.error('Error sending test push:', err);
      setTestPushMessage('✗ Errore nella connessione');
    } finally {
      setTestPushLoading(false);
    }
  }

  if (diagnostics.loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin">Caricamento...</div>
      </div>
    );
  }

  return (
    <div className="container max-w-2xl mx-auto py-8 px-4">
      <div className="space-y-6">
        {/* Title */}
        <div>
          <h1 className="text-3xl font-bold">Debug Web Push Notifications</h1>
          <p className="text-muted-foreground mt-2">
            Diagnostica dello stato delle notifiche push su questo dispositivo.
          </p>
        </div>

        {/* Diagnostic State */}
        <Card>
          <CardHeader>
            <CardTitle>Stato Dispositivo</CardTitle>
            <CardDescription>Informazioni sulla PWA e Service Worker</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <DiagnosticRow
              label="PWA Standalone"
              value={diagnostics.pwaStandalone ? 'Sì' : 'No'}
              isGood={diagnostics.pwaStandalone}
            />
            <DiagnosticRow
              label="Service Worker Supportato"
              value={diagnostics.serviceWorkerSupported ? 'Sì' : 'No'}
              isGood={diagnostics.serviceWorkerSupported}
            />
            <DiagnosticRow
              label="Service Worker Attivo"
              value={diagnostics.serviceWorkerActive ? 'Sì' : 'No'}
              isGood={diagnostics.serviceWorkerActive}
            />
            <DiagnosticRow
              label="Service Worker Controllante"
              value={diagnostics.serviceWorkerControlling ? 'Sì' : 'No'}
              isGood={diagnostics.serviceWorkerControlling}
            />
            <DiagnosticRow
              label="Push Manager Supportato"
              value={diagnostics.pushManagerSupported ? 'Sì' : 'No'}
              isGood={diagnostics.pushManagerSupported}
            />
          </CardContent>
        </Card>

        {/* Permission State */}
        <Card>
          <CardHeader>
            <CardTitle>Permessi Notifiche</CardTitle>
            <CardDescription>Stato del permesso e della subscription</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <DiagnosticRow
              label="Notification Permission"
              value={diagnostics.notificationPermission || 'default'}
              isGood={diagnostics.notificationPermission === 'granted'}
            />
            <DiagnosticRow
              label="Subscription Presente (Locale)"
              value={diagnostics.subscriptionPresent ? 'Sì' : 'No'}
              isGood={diagnostics.subscriptionPresent}
            />
            <DiagnosticRow
              label="Subscription nel Database"
              value={diagnostics.subscriptionInDatabase ? 'Sì' : 'No'}
              isGood={diagnostics.subscriptionInDatabase}
            />
          </CardContent>
        </Card>

        {/* Last Attempt */}
        {diagnostics.lastAttemptTime && (
          <Card>
            <CardHeader>
              <CardTitle>Ultimo Tentativo</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <DiagnosticRow
                label="Tentativo"
                value={new Date(diagnostics.lastAttemptTime).toLocaleString()}
              />
              {diagnostics.lastDeliveryStatus && (
                <DiagnosticRow label="Stato Delivery" value={diagnostics.lastDeliveryStatus} />
              )}
            </CardContent>
          </Card>
        )}

        {/* Error */}
        {diagnostics.sanitizedError && (
          <Alert variant="destructive">
            <AlertDescription>{diagnostics.sanitizedError}</AlertDescription>
          </Alert>
        )}

        {/* Test Message */}
        {testPushMessage && (
          <Alert variant={testPushMessage.startsWith('✓') ? 'default' : 'destructive'}>
            <AlertDescription>{testPushMessage}</AlertDescription>
          </Alert>
        )}

        {/* Actions */}
        <div className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <Button onClick={handleEnableNotifications} className="w-full">
              Attiva Notifiche
            </Button>
            <Button onClick={handleRecreateSubscription} className="w-full" variant="outline">
              Ricrea Subscription
            </Button>
          </div>
          <Button
            onClick={handleSendTestPush}
            disabled={testPushLoading || !diagnostics.subscriptionInDatabase}
            className="w-full"
            variant="default"
          >
            {testPushLoading ? 'Invio in corso...' : 'Invia Notifica di Prova'}
          </Button>
        </div>

        {/* Warning */}
        {!diagnostics.subscriptionInDatabase && (
          <Alert>
            <AlertDescription>
              ⚠️ Per inviare una notifica di prova, attiva prima le notifiche e crea una subscription.
            </AlertDescription>
          </Alert>
        )}
      </div>
    </div>
  );
}

// Helper component
function DiagnosticRow({
  label,
  value,
  isGood,
}: {
  label: string;
  value: string;
  isGood?: boolean;
}) {
  const icon = isGood === undefined ? '○' : isGood ? '✓' : '✗';
  const color = isGood === undefined ? 'text-gray-500' : isGood ? 'text-green-600' : 'text-red-600';

  return (
    <div className="flex justify-between items-center py-2 border-b last:border-b-0">
      <span className="text-sm font-medium text-muted-foreground">{label}</span>
      <span className={`text-sm font-semibold ${color}`}>
        {icon} {value}
      </span>
    </div>
  );
}
