/* مكتبي — بيخلي البرنامج يفتح من غير نت بعد أول مرة. مفيش أي بيانات بتعدي من هنا — البيانات في IndexedDB متشفرة. */
var C = 'maktabi-9d4ce8ea07';
var CORE = ['./', './index.html', './manifest.webmanifest', './icon-180.png', './icon-192.png', './icon-512.png'];
self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(C).then(function (c) { return c.addAll(CORE); }).then(function () { return self.skipWaiting(); }));
});
self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (ks) { return Promise.all(ks.filter(function (k) { return k !== C; }).map(function (k) { return caches.delete(k); })); }).then(function () { return self.clients.claim(); }));
});
self.addEventListener('fetch', function (e) {
  var req = e.request, u = new URL(req.url);
  if (req.method !== 'GET') return;
  if (u.origin === self.location.origin) {
    e.respondWith(caches.match(req, { ignoreSearch: true }).then(function (hit) {
      var net = fetch(req).then(function (res) {
        if (res && res.ok) { var copy = res.clone(); caches.open(C).then(function (c) { c.put(req, copy); }); }
        return res;
      }).catch(function () { return hit || caches.match('./index.html'); });
      return hit || net;
    }));
  } else if (/fonts\.(googleapis|gstatic)\.com$/.test(u.hostname)) {
    e.respondWith(caches.match(req).then(function (hit) {
      return hit || fetch(req).then(function (res) { var copy = res.clone(); caches.open(C).then(function (c) { c.put(req, copy); }); return res; });
    }));
  }
});
