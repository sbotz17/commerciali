// Servizio Web Push con implementazione web e stub per le altre piattaforme.
//
// Il client JavaScript è in `web/push/push-client.js`; il service worker è in
// `web/push/push-sw.js` con scope `/push/`, separato dal service worker di
// Flutter.

import 'web_push_service_stub.dart'
    if (dart.library.js_interop) 'web_push_service_web.dart' as impl;

/// Il server push (Cloud Function) è attivo solo in produzione. In staging il
/// pulsante resta disattivato per non salvare sottoscrizioni senza invio.
const bool pushDisponibileAmbiente =
    String.fromEnvironment('APP_ENV', defaultValue: 'staging') == 'prod';

/// Esito della richiesta di iscrizione alle notifiche push.
class EsitoPush {
  const EsitoPush({
    required this.ok,
    this.endpoint,
    this.p256dh,
    this.auth,
    this.userAgent,
    this.errore,
  });

  factory EsitoPush.daJson(Map<String, dynamic> json) {
    return EsitoPush(
      ok: json['ok'] == true,
      endpoint: json['endpoint'] as String?,
      p256dh: json['p256dh'] as String?,
      auth: json['auth'] as String?,
      userAgent: json['userAgent'] as String?,
      errore: json['errore'] as String?,
    );
  }

  final bool ok;
  final String? endpoint;
  final String? p256dh;
  final String? auth;
  final String? userAgent;
  final String? errore;

  bool get completa =>
      ok &&
      (endpoint ?? '').trim().isNotEmpty &&
      (p256dh ?? '').trim().isNotEmpty &&
      (auth ?? '').trim().isNotEmpty;

  /// Messaggio italiano pronto per l'utente.
  String get messaggio {
    if (ok) return 'Notifiche attivate su questo dispositivo.';
    final errore = (this.errore ?? '').trim();
    return errore.isEmpty
        ? 'Non è stato possibile attivare le notifiche.'
        : errore;
  }
}

/// Servizio push: usa il JavaScript su web, altrimenti restituisce uno stub.
class WebPushService {
  const WebPushService();

  bool get supportato => impl.supportato;

  Future<EsitoPush> iscrivi() async {
    final raw = await impl.iscrivi();
    return EsitoPush.daJson(raw);
  }

  Future<void> annulla() => impl.annulla();
}
