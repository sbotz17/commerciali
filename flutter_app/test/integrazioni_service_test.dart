import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/condivisione_calendario.dart';
import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('condivisioneCalendarioValida', () {
    test('uid vuoti o assenti sono invalidi', () {
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: null,
          destinatarioUid: 'u-2',
          livello: 'dettagli',
        ),
        isFalse,
      );
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: 'u-1',
          destinatarioUid: null,
          livello: 'dettagli',
        ),
        isFalse,
      );
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: '',
          destinatarioUid: 'u-2',
          livello: 'dettagli',
        ),
        isFalse,
      );
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: '  ',
          destinatarioUid: 'u-2',
          livello: 'dettagli',
        ),
        isFalse,
      );
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: 'u-1',
          destinatarioUid: '  ',
          livello: 'dettagli',
        ),
        isFalse,
      );
    });

    test('condivisione con se stessi è invalida', () {
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: 'u-1',
          destinatarioUid: 'u-1',
          livello: 'dettagli',
        ),
        isFalse,
      );
    });

    test('livello non valido o null è invalido', () {
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: 'u-1',
          destinatarioUid: 'u-2',
          livello: null,
        ),
        isFalse,
      );
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: 'u-1',
          destinatarioUid: 'u-2',
          livello: 'tutto',
        ),
        isFalse,
      );
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: 'u-1',
          destinatarioUid: 'u-2',
          livello: '',
        ),
        isFalse,
      );
    });

    test('uid diversi non vuoti e livello valido sono validi', () {
      for (final livello in ['libero_occupato', 'dettagli', 'modifica']) {
        expect(
          condivisioneCalendarioValida(
            proprietarioUid: 'u-1',
            destinatarioUid: 'u-2',
            livello: livello,
          ),
          isTrue,
          reason: 'livello $livello deve essere valido',
        );
      }
      // il trim degli uid non interferisce con la validità
      expect(
        condivisioneCalendarioValida(
          proprietarioUid: ' u-1 ',
          destinatarioUid: ' u-2 ',
          livello: 'dettagli',
        ),
        isTrue,
      );
    });
  });

  group('condivisioniAttive', () {
    test('tiene solo le condivisioni attive', () {
      final attiva1 = CondivisioneCalendario(id: 's-1', stato: 'attiva');
      final revocata =
          CondivisioneCalendario(id: 's-2', stato: 'revocata');
      final attiva2 = CondivisioneCalendario(id: 's-3', stato: 'attiva');

      final risultato = condivisioniAttive([attiva1, revocata, attiva2]);

      expect(risultato.map((c) => c.id), ['s-1', 's-3']);
    });

    test('lista vuota restituisce lista vuota', () {
      expect(condivisioniAttive([]), isEmpty);
    });
  });

  group('confrontaCondivisioniPerData', () {
    test('ordina per createdAt discendente (le più recenti per prime)', () {
      final vecchia = CondivisioneCalendario(
        id: 's-1',
        createdAt: '2026-10-01T10:00:00Z',
      );
      final nuova = CondivisioneCalendario(
        id: 's-2',
        createdAt: '2026-10-03T10:00:00Z',
      );
      final media = CondivisioneCalendario(
        id: 's-3',
        createdAt: '2026-10-02T10:00:00Z',
      );

      final ordinati = [vecchia, nuova, media]
        ..sort(confrontaCondivisioniPerData);

      expect(ordinati.map((c) => c.id), ['s-2', 's-3', 's-1']);
    });

    test('i valori null finiscono in fondo', () {
      final conData = CondivisioneCalendario(
        id: 's-1',
        createdAt: '2026-10-01T10:00:00Z',
      );
      final senzaData = CondivisioneCalendario(id: 's-2');
      final senzaData2 = CondivisioneCalendario(id: 's-3');

      final ordinati = [senzaData, conData, senzaData2]
        ..sort(confrontaCondivisioniPerData);

      expect(ordinati.first.id, 's-1');
      expect(ordinati.map((c) => c.id).where((id) => id != 's-1').toSet(),
          {'s-2', 's-3'});
    });

    test('date uguali mantengono l\'ordine relativo (confronto stabile)', () {
      final a = CondivisioneCalendario(
        id: 's-1',
        createdAt: '2026-10-01T10:00:00Z',
      );
      final b = CondivisioneCalendario(
        id: 's-2',
        createdAt: '2026-10-01T10:00:00Z',
      );

      expect(confrontaCondivisioniPerData(a, b), 0);
      expect(confrontaCondivisioniPerData(b, a), 0);
    });
  });
}
