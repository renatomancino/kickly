const CACHE = "kickly-shell-v2";
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
  const legacyLink = payload.data && typeof payload.data.url === "string" ? payload.data.url : null;
  const link = typeof payload.link === "string" ? payload.link : legacyLink || "/notifications";
  event.waitUntil(self.registration.showNotification(repairUtf8Mojibake(payload.title || "Kickly"), {
    body: repairUtf8Mojibake(payload.body || "Hai una nuova notifica"),
    icon: payload.icon || "/icons/kickly-icon-192.png",
    badge: payload.badge || "/icons/badge-72x72.png",
    tag: payload.id || undefined,
    data: { link },
    vibrate: [120, 40, 120],
  }));
});

function repairUtf8Mojibake(value) {
  const windows1252Bytes = new Map([
    [0x20ac, 0x80], [0x201a, 0x82], [0x0192, 0x83], [0x201e, 0x84], [0x2026, 0x85],
    [0x2020, 0x86], [0x2021, 0x87], [0x02c6, 0x88], [0x2030, 0x89], [0x0160, 0x8a],
    [0x2039, 0x8b], [0x0152, 0x8c], [0x017d, 0x8e], [0x2018, 0x91], [0x2019, 0x92],
    [0x201c, 0x93], [0x201d, 0x94], [0x2022, 0x95], [0x2013, 0x96], [0x2014, 0x97],
    [0x02dc, 0x98], [0x2122, 0x99], [0x0161, 0x9a], [0x203a, 0x9b], [0x0153, 0x9c],
    [0x017e, 0x9e], [0x0178, 0x9f],
  ]);
  const markers = new Set([0x00c2, 0x00c3, 0x00e2, 0x00ef, 0x00f0]);
  const score = (text) => [...text].filter((character) => markers.has(character.codePointAt(0) || 0)).length;
  let candidate = String(value);
  for (let pass = 0; pass < 3; pass += 1) {
    const candidateScore = score(candidate);
    if (!candidateScore) break;
    const bytes = [];
    let convertible = true;
    for (const character of candidate) {
      const codePoint = character.codePointAt(0) || 0;
      const byte = codePoint <= 0xff ? codePoint : windows1252Bytes.get(codePoint);
      if (byte === undefined) { convertible = false; break; }
      bytes.push(byte);
    }
    if (!convertible) break;
    try {
      const decoded = new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(bytes));
      if (score(decoded) >= candidateScore) break;
      candidate = decoded;
    } catch { break; }
  }
  return candidate;
}

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.link || "/notifications", self.location.origin).href;
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
    const existing = clients.find((client) => client.url === target);
    if (existing) return existing.focus();
    return self.clients.openWindow(target);
  }));
});
