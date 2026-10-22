import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Risultato di una verifica P.IVA VIES.
///
/// Riflette la risposta del Worker VIES (`{ok, valido, piva, name, address}`):
/// [valido] indica se VIES riconosce la partita IVA, [ragioneSociale] e
/// [indirizzo] sono vuoti quando non valida, [errore] è valorizzato quando il
/// Worker segnala un problema (`ok: false` con campo `error`).
class ViesRisultato {
  const ViesRisultato({
    required this.valido,
    required this.piva,
    this.ragioneSociale,
    this.indirizzo,
    this.errore,
  });

  /// `true` se VIES riconosce la partita IVA.
  final bool valido;

  /// Partita IVA normalizzata (11 cifre) verificata.
  final String piva;

  /// Ragione sociale, se presente nella risposta VIES.
  final String? ragioneSociale;

  /// Indirizzo (sede legale), se presente nella risposta VIES.
  final String? indirizzo;

  /// Messaggio d'errore in italiano, se la verifica non è andata a buon fine.
  final String? errore;

  /// Costruisce il risultato dalla risposta JSON del Worker VIES.
  ///
  /// Legge `name` e `address` (nomi usati dal Worker) e li espone come
  /// [ragioneSociale] e [indirizzo]; `error` diventa [errore]. I campi mancanti
  /// vengono normalizzati a valori vuoti, così il modello è sempre coerente.
  factory ViesRisultato.fromJson(Map<String, dynamic> json) {
    final errore = (json['error'] as String?)?.trim();
    return ViesRisultato(
      valido: json['valido'] == true,
      piva: (json['piva'] as String?) ?? '',
      ragioneSociale: _vuotoSeAssente(json['name']),
      indirizzo: _vuotoSeAssente(json['address']),
      errore: (errore == null || errore.isEmpty) ? null : errore,
    );
  }

  static String? _vuotoSeAssente(dynamic valore) {
    final testo = (valore as String?)?.trim();
    return (testo == null || testo.isEmpty) ? null : testo;
  }
}

/// Errore di verifica P.IVA con messaggio già tradotto in italiano.
class ViesException implements Exception {
  const ViesException(this.message);

  final String message;

  @override
  String toString() => 'ViesException: $message';
}

/// Normalizza una Partita IVA per la verifica VIES: solo 11 cifre, senza
/// prefisso `IT` e senza altri caratteri (spazi, punti, ecc.).
///
/// Ritorna `null` se il valore è vuoto o assente.
String? normalizzaPivaVies(String value) {
  var p = value.trim().toUpperCase();
  if (p.startsWith('IT')) p = p.substring(2);
  p = p.replaceAll(RegExp(r'\D'), '');
  return p.isEmpty ? null : p;
}

/// Proxy VIES per la verifica della Partita IVA (Cloudflare Worker).
///
/// Nessuna dipendenza da Firebase né da UI: riceve la P.IVA, chiama il Worker
/// e restituisce un [ViesRisultato]. Gli errori sono sempre in italiano.
class ViesService {
  ViesService({
    http.Client? client,
    this.endpoint = 'https://commerciali-vies.bottiandrea83.workers.dev/',
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Endpoint del Worker VIES (sovrascrivibile nei test).
  final String endpoint;

  /// Timeout della chiamata HTTP (il Worker usa a sua volta 20s verso VIES).
  static const Duration timeout = Duration(seconds: 20);

  /// Chiude il client HTTP sottostante. Da chiamare quando il servizio non
  /// serve più (ad esempio nel `dispose` della schermata che lo possiede).
  void close() => _client.close();

  /// Verifica una Partita IVA: normalizza, chiama il Worker e interpreta la
  /// risposta. Lancia [ViesException] con messaggio in italiano in caso di
  /// errore di input, rete, timeout o risposta non interpretabile.
  Future<ViesRisultato> verifica(String piva) async {
    final normalizzata = normalizzaPivaVies(piva);
    if (normalizzata == null || normalizzata.length != 11) {
      throw const ViesException('La P.IVA deve avere 11 cifre.');
    }

    try {
      final risposta = await _client
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'piva': normalizzata}),
          )
          .timeout(timeout);

      final Map<String, dynamic> corpo;
      try {
        corpo = jsonDecode(risposta.body) as Map<String, dynamic>;
      } catch (_) {
        throw const ViesException(
          'Risposta non valida dal servizio di verifica. Riprova.',
        );
      }

      return ViesRisultato.fromJson(corpo);
    } on ViesException {
      rethrow;
    } on TimeoutException {
      throw const ViesException(
        'Verifica scaduta. Il servizio VIES non risponde. Riprova.',
      );
    } catch (_) {
      throw const ViesException(
        'Impossibile verificare la P.IVA. Controlla la connessione e riprova.',
      );
    }
  }
}
