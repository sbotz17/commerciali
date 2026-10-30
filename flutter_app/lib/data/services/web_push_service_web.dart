// Implementazione Web Push per il browser.
import 'dart:convert';
import 'dart:js_interop';

@JS('CloserPush')
external _CloserPush get _closerPush;

extension type _CloserPush(JSObject _) implements JSObject {
  external bool get supportato;
  external JSPromise<JSString> iscrivi();
  external JSPromise<JSString> annulla();
}

bool get supportato => _closerPush.supportato;

Future<Map<String, dynamic>> iscrivi() async {
  final risultato = await _closerPush.iscrivi().toDart;
  final testo = risultato.toDart;
  final decodificato = jsonDecode(testo);
  return decodificato is Map<String, dynamic>
      ? decodificato
      : <String, dynamic>{'ok': false, 'errore': 'Risposta push non valida.'};
}

Future<void> annulla() async {
  await _closerPush.annulla().toDart;
}
