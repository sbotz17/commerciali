// Client Web Push di Closer.
// Registra un service worker con scope /push/ (separato dal service worker di
// Flutter) e salva la sottoscrizione tramite l'app Dart.
(function () {
  "use strict";

  // Chiave pubblica VAPID (sicura da esporre: la chiave privata resta sul server).
  var VAPID_PUBLIC_KEY =
    "BEIad0euv_RLN4nE3g7YyESuHliy-qFvY_cGRIpTQUaweiBz65CuD031NHHzUr0k9kMEw8JTKpcYGrrVTHwfkMk";

  function urlBase64ToUint8Array(base64String) {
    var padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    var base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    var raw = atob(base64);
    var output = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; ++i) output[i] = raw.charCodeAt(i);
    return output;
  }

  function supportato() {
    return (
      "serviceWorker" in navigator &&
      "PushManager" in window &&
      "Notification" in window
    );
  }

  async function registra() {
    var reg = await navigator.serviceWorker.register("/push/push-sw.js", {
      scope: "/push/",
    });
    await navigator.serviceWorker.ready;
    return reg;
  }

  async function iscrivi() {
    try {
      if (!supportato()) {
        return JSON.stringify({
          ok: false,
          errore: "Questo browser non supporta le notifiche push.",
        });
      }
      var permesso = await Notification.requestPermission();
      if (permesso !== "granted") {
        return JSON.stringify({
          ok: false,
          errore:
            "Permesso notifiche negato. Attivalo dalle impostazioni del browser.",
        });
      }
      var reg = await registra();
      var sub = await reg.pushManager.getSubscription();
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
        });
      }
      var json = sub.toJSON();
      return JSON.stringify({
        ok: true,
        endpoint: json.endpoint,
        p256dh: json.keys.p256dh,
        auth: json.keys.auth,
        userAgent: navigator.userAgent,
      });
    } catch (e) {
      return JSON.stringify({
        ok: false,
        errore: e && e.message ? e.message : String(e),
      });
    }
  }

  async function annulla() {
    try {
      if (!supportato()) return JSON.stringify({ ok: true });
      var reg = await navigator.serviceWorker.getRegistration("/push/");
      if (!reg) return JSON.stringify({ ok: true });
      var sub = await reg.pushManager.getSubscription();
      if (sub) await sub.unsubscribe();
      return JSON.stringify({ ok: true });
    } catch (e) {
      return JSON.stringify({
        ok: false,
        errore: e && e.message ? e.message : String(e),
      });
    }
  }

  window.CloserPush = {
    supportato: supportato(),
    iscrivi: iscrivi,
    annulla: annulla,
  };
})();
