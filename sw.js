/* Service worker: aplikácia sa dá nainštalovať a základné súbory sa uložia.
   Stránka sa berie prednostne zo siete (aby prišli nové verzie), pri výpadku z uloženej kópie.
   Požiadavky na databázu (Supabase) sa nikdy neukladajú. */
const CACHE = "tetris-v8";
const SUBORY = ["./", "index.html", "manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SUBORY)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(kluce =>
    Promise.all(kluce.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ).then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== location.origin) return;  // len vlastné súbory
  e.respondWith(
    fetch(req, { cache: "no-cache" }).then(res => {
      const kopia = res.clone();
      caches.open(CACHE).then(c => c.put(req, kopia));
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match("index.html")))
  );
});
