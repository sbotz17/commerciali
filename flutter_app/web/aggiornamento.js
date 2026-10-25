// Aggiornamento automatico della web app (PWA) di Closer.
//
// Flutter tiene l'app in una cache del service worker: senza questo controllo
// una nuova versione può restare invisibile finché non si chiude e riapre due
// volte. Qui, prima di caricare Flutter, si confronta l'impronta del service
// worker sul server con quella dell'ultima apertura: se è cambiata si
// cancellano cache e service worker e si ricarica una volta sola.
//
// Il controllo gira all'apertura e quando l'app torna visibile (al massimo una
// volta ogni 2 minuti). La sessione di Firebase non viene toccata: dopo il
// ricaricamento l'utente resta collegato.
(function () {
  var CHIAVE = 'closer_sw_impronta';
  var GUARDIA = 'closer_sw_ricarica';
  var ATTESA_CONTROLLO = 60 * 1000;
  var ultimoControllo = 0;

  function impronta(testo) {
    // Hash semplice e stabile: serve solo a capire se il file è cambiato.
    var h = 5381;
    for (var i = 0; i < testo.length; i++) {
      h = ((h << 5) + h + testo.charCodeAt(i)) | 0;
    }
    return String(h) + '-' + testo.length;
  }

  function leggiServiceWorker() {
    // Il parametro evita la cache del service worker e del browser.
    return fetch('/flutter_service_worker.js?controllo=' + Date.now(), {
      cache: 'no-store',
      credentials: 'same-origin',
    }).then(function (risposta) {
      if (!risposta.ok) return null;
      return risposta.text();
    });
  }

  function svuotaCache() {
    var lavori = [];
    if (window.caches && caches.keys) {
      lavori.push(
        caches.keys().then(function (chiavi) {
          return Promise.all(
            chiavi.map(function (chiave) {
              return caches.delete(chiave);
            })
          );
        })
      );
    }
    if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
      lavori.push(
        navigator.serviceWorker
          .getRegistrations()
          .then(function (registrazioni) {
            return Promise.all(
              registrazioni.map(function (registrazione) {
                return registrazione.unregister();
              })
            );
          })
      );
    }
    return Promise.all(lavori);
  }

  function controlla() {
    var ora = Date.now();
    if (ora - ultimoControllo < ATTESA_CONTROLLO) return;
    ultimoControllo = ora;

    leggiServiceWorker()
      .then(function (testo) {
        if (!testo) return;
        var nuova = impronta(testo);
        var vecchia = null;
        try {
          vecchia = localStorage.getItem(CHIAVE);
        } catch (_) {}
        if (!vecchia) {
          // Prima apertura: si memorizza e basta.
          try {
            localStorage.setItem(CHIAVE, nuova);
          } catch (_) {}
          return;
        }
        if (vecchia === nuova) return;

        // Evita un ciclo di ricaricamenti se il file cambia di nuovo subito.
        var ultima = 0;
        try {
          ultima = Number(sessionStorage.getItem(GUARDIA) || 0);
        } catch (_) {}
        if (ora - ultima < 60000) return;
        try {
          sessionStorage.setItem(GUARDIA, String(ora));
          localStorage.setItem(CHIAVE, nuova);
        } catch (_) {}

        svuotaCache().then(function () {
          window.location.reload();
        });
      })
      .catch(function () {
        // Rete assente o file non disponibile: si riprova alla prossima apertura.
      });
  }

  controlla();

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') controlla();
  });
})();
