/* bb-dev-system service worker.

   NETWORK-FIRST, so a new build always wins. A cache-first worker is how a team
   ends up staring at a board that moved on hours ago.

   THE RULE THIS EXISTS TO KEEP: never cache the database. Live rows are the
   state of somebody's work, and a stale one gets acted on.
*/
const CACHE_PREFIX = 'bb-dev-system-';
const CACHE = CACHE_PREFIX + 'v1';
const SHELL = ['./', './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
/* DEV-6, 6 Oct 2026: this deleted EVERY cache that was not bb-dev-system-v1.
   Caches belong to the origin, not the app. All six BB apps share one
   origin, so opening Dev wiped the Video, Graphic, SMM, Leads and Command Centre
   offline shells. Only this app's own old caches are cleared now. */
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k.indexOf(CACHE_PREFIX) === 0 && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.indexOf('/rest/v1/') > -1 || url.pathname.indexOf('/auth/v1/') > -1) return;
  e.respondWith(
    fetch(req)
      .then(res => {
        if (res && res.status === 200) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() => caches.match(req).then(hit => hit || caches.match('./')))
  );
});

/* ── BB PUSH (hub build 2026-09-04) ──────────────────────────────────────────
   Receives a push from the bb-push edge function and shows it. A tap opens
   the app at the URL the alert carried, focusing an open window if there is
   one rather than stacking a second copy. Nothing here touches the cache
   rules above. */
self.addEventListener('push', function (event) {
  var data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) { data = { body: event.data ? event.data.text() : '' }; }
  var title = data.title || 'Business Booster';
  var opts = {
    body: data.body || 'Open the app to see what changed.',
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: data.tag || 'bb-alert',
    renotify: true,
    data: { url: data.url || './' }
  };
  event.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || './';
  /* DEV-6, 6 Oct 2026: includeUncontrolled lists every window on the shared
     origin, so this focused the FIRST one, which could be the Video or SMM app.
     Only a window inside this worker's scope (a Dev window) is reused now;
     otherwise a new Dev window opens. */
  var scope = self.registration.scope;
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].url || '').indexOf(scope) !== 0) continue;
      if ('focus' in list[i]) { list[i].navigate && list[i].navigate(target); return list[i].focus(); }
    }
    return clients.openWindow(target);
  }));
});
