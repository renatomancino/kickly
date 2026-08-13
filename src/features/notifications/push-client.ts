export type PushSetupErrorCode = "unsupported" | "permission" | "config" | "save" | "remove";

export class PushSetupError extends Error {
  constructor(public readonly code: PushSetupErrorCode) {
    super(code);
    this.name = "PushSetupError";
  }
}

export function supportsWebPush() {
  return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
}

export function isStandaloneApp() {
  const iosNavigator = navigator as Navigator & { standalone?: boolean };
  return window.matchMedia("(display-mode: standalone)").matches || iosNavigator.standalone === true;
}

export function isIosDevice() {
  return /iphone|ipad|ipod/i.test(navigator.userAgent);
}

export async function getReadyServiceWorker() {
  if (!supportsWebPush()) throw new PushSetupError("unsupported");
  await navigator.serviceWorker.register("/sw.js");
  return navigator.serviceWorker.ready;
}

export async function getDevicePushSubscription() {
  const registration = await getReadyServiceWorker();
  return registration.pushManager.getSubscription();
}

export async function syncDevicePushSubscription(subscription: PushSubscription) {
  const json = subscription.toJSON();
  if (!json.keys?.p256dh || !json.keys.auth) throw new PushSetupError("save");
  const response = await fetch("/api/push/subscribe", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      endpoint: subscription.endpoint,
      keys: json.keys,
      deviceName: deviceLabel(),
    }),
  });
  if (!response.ok) throw new PushSetupError("save");
}

export async function enablePushOnDevice() {
  const registration = await getReadyServiceWorker();
  const permission = await Notification.requestPermission();
  if (permission !== "granted") throw new PushSetupError("permission");

  let subscription = await registration.pushManager.getSubscription();
  let createdSubscription = false;
  if (!subscription) {
    const keyResponse = await fetch("/api/push/public-key", { cache: "no-store" });
    if (!keyResponse.ok) throw new PushSetupError("config");
    const { key } = (await keyResponse.json()) as { key?: string };
    if (!key) throw new PushSetupError("config");
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(key) as BufferSource,
    });
    createdSubscription = true;
  }

  try {
    await syncDevicePushSubscription(subscription);
  } catch (error) {
    if (createdSubscription) await subscription.unsubscribe().catch(() => false);
    throw error;
  }
  return subscription;
}

export async function disablePushOnDevice() {
  const subscription = await getDevicePushSubscription();
  if (!subscription) return;
  const response = await fetch("/api/push/subscribe", {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ endpoint: subscription.endpoint }),
  });
  if (!response.ok) throw new PushSetupError("remove");
  await subscription.unsubscribe();
}

export function pushErrorMessage(error: unknown) {
  if (!(error instanceof PushSetupError)) return "Attivazione push non riuscita.";
  if (error.code === "permission") return "Permesso notifiche non concesso.";
  if (error.code === "unsupported") return "Questo browser non supporta le notifiche push.";
  if (error.code === "remove") return "Disattivazione push non riuscita.";
  if (error.code === "config") return "Configurazione push non disponibile.";
  return "Attivazione push non riuscita.";
}

function urlBase64ToUint8Array(base64: string) {
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const raw = atob((base64 + padding).replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from([...raw].map((char) => char.charCodeAt(0)));
}

function deviceLabel() {
  if (isIosDevice()) return "iPhone/iPad";
  if (/android/i.test(navigator.userAgent)) return "Android";
  return "Browser desktop";
}
