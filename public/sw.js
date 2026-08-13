const CACHE = "kickly-shell-v1";
const OFFLINE_ASSETS = ["/offline", "/manifest.webmanifest", "/icons/kickly-icon-192.png", "/icons/kickly-icon-512.png", "/icons/kickly-maskable-512.png", "/icons/apple-touch-icon.png", "/icons/badge.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(OFFLINE_ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET" || event.request.mode !== "navigate") return;
  event.respondWith(fetch(event.request).catch(() => caches.match("/offline")));
});

self.addEventListener("push", (event) => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch { payload = { body: event.data?.text() }; }
  event.waitUntil(self.registration.showNotification(payload.title || "Kickly", {
    body: payload.body || "Hai una nuova notifica",
    icon: "/icons/kickly-icon-192.png",
    badge: "/icons/badge.svg",
    tag: payload.id || undefined,
    data: { link: payload.link || "/notifications" },
    vibrate: [120, 40, 120],
  }));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.link || "/notifications", self.location.origin).href;
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
    const existing = clients.find((client) => client.url === target);
    if (existing) return existing.focus();
    return self.clients.openWindow(target);
  }));
});
