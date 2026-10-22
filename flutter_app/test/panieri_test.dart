import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/preventivo.dart';
import 'package:commerciali_app/data/models/prodotto.dart';
import 'package:commerciali_app/data/panieri.dart';

void main() {
  group('figliDelPaniere', () {
    test('segue ordine, esclude padre, non attivi e duplicati', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Paniere',
        figliIds: const ['p-1', 'f-1', 'f-2', 'f-3', 'f-1'],
      );
      final f1 = Prodotto(id: 'f-1', nome: 'Figlio 1', attivo: true);
      final f2 = Prodotto(id: 'f-2', nome: 'Figlio 2', attivo: false);
      final tutti = <Prodotto>[f1, f2, padre];

      final figli = figliDelPaniere(padre, tutti);

      expect(figli.map((f) => f.id).toList(), ['f-1']);
    });
  });

  group('figliMancanti', () {
    test('id inesistenti o non attivi (escluso il padre)', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Paniere',
        figliIds: const ['p-1', 'f-1', 'f-2', 'f-3', 'f-1'],
      );
      final f1 = Prodotto(id: 'f-1', nome: 'Figlio 1', attivo: true);
      final f2 = Prodotto(id: 'f-2', nome: 'Figlio 2', attivo: false);
      final tutti = <Prodotto>[f1, f2, padre];

      final mancanti = figliMancanti(padre, tutti);

      expect(mancanti, ['f-2', 'f-3']);
    });
  });

  group('inserisciPaniere', () {
    test('padre nuovo senza figli → aggiunge solo la riga padre', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
        immagine: 'https://x/img.png',
      );

      final righe = inserisciPaniere(padre: padre, figli: const [], righe: []);

      expect(righe, hasLength(1));
      final r = righe.single;
      expect(r.prodottoId, 'p-1');
      expect(r.nome, 'Pacchetto');
      expect(r.prezzo, 100);
      expect(r.immagine, 'https://x/img.png');
      expect(r.qty, 1);
      expect(r.um, 'pz');
      expect(r.ivaPerc, 22);
      expect(r.paniereId, isNull);
    });

    test('padre con 2 figli → riga padre + due figlie con qty 1', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
        figliIds: const ['f-1', 'f-2'],
      );
      final f1 = Prodotto(id: 'f-1', nome: 'Figlio 1', prezzo: 20);
      final f2 = Prodotto(id: 'f-2', nome: 'Figlio 2', prezzo: 30);

      final righe =
          inserisciPaniere(padre: padre, figli: [f1, f2], righe: const []);

      expect(righe, hasLength(3));

      final rigaPadre = righe.firstWhere((r) => r.prodottoId == 'p-1');
      expect(rigaPadre.qty, 1);
      expect(rigaPadre.paniereId, isNull);

      final figlie =
          righe.where((r) => r.paniereId == 'p-1').toList()..sort(
              (a, b) => (a.prodottoId ?? '').compareTo(b.prodottoId ?? ''));
      expect(figlie, hasLength(2));
      expect(figlie[0].prodottoId, 'f-1');
      expect(figlie[0].qty, 1);
      expect(figlie[0].prezzo, 20);
      expect(figlie[0].paniereNome, 'Pacchetto');
      expect(figlie[1].prodottoId, 'f-2');
      expect(figlie[1].prezzo, 30);
    });

    test('figliAZero → figlie con prezzo 0 (padre invariato)', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
        figliAZero: true,
        figliIds: const ['f-1'],
      );
      final f1 = Prodotto(id: 'f-1', nome: 'Figlio', prezzo: 50);

      final righe = inserisciPaniere(padre: padre, figli: [f1], righe: const []);

      final figlia = righe.firstWhere((r) => r.prodottoId == 'f-1');
      expect(figlia.prezzo, 0);
      expect(righe.firstWhere((r) => r.prodottoId == 'p-1').prezzo, 100);
    });

    test('padre già presente → qty+1 senza ricalcolare il prezzo', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
      );
      final esistente = PreventivoRiga(
        prodottoId: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
        qty: 2,
        um: 'pz',
        ivaPerc: 22,
      );

      final righe = inserisciPaniere(
        padre: padre,
        figli: const [],
        righe: [esistente],
      );

      expect(righe, hasLength(1));
      expect(righe.single.qty, 3);
      expect(righe.single.prezzo, 100);
    });

    test('figlio adottato da riga singola → paniere collegato, qty+1', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
        figliIds: const ['f-1'],
      );
      final f1 = Prodotto(id: 'f-1', nome: 'Figlio', prezzo: 30);
      final rigaLibera = PreventivoRiga(
        prodottoId: 'f-1',
        nome: 'Figlio',
        prezzo: 30,
        qty: 1,
        um: 'pz',
        ivaPerc: 22,
      );

      final righe = inserisciPaniere(
        padre: padre,
        figli: [f1],
        righe: [rigaLibera],
      );

      expect(righe, hasLength(2));
      final figlia = righe.firstWhere((r) => r.prodottoId == 'f-1');
      expect(figlia.paniereId, 'p-1');
      expect(figlia.paniereNome, 'Pacchetto');
      expect(figlia.qty, 2);
      expect(figlia.prezzo, 30);
    });

    test('figlio già sotto un altro paniere → nuova riga, esistente intatta', () {
      final padre = Prodotto(
        id: 'p-1',
        nome: 'Pacchetto',
        prezzo: 100,
        figliIds: const ['f-1'],
      );
      final f1 = Prodotto(id: 'f-1', nome: 'Figlio', prezzo: 30);
      final rigaAltro = PreventivoRiga(
        prodottoId: 'f-1',
        nome: 'Figlio',
        prezzo: 30,
        qty: 5,
        paniereId: 'altro',
        paniereNome: 'Altro',
      );

      final righe = inserisciPaniere(
        padre: padre,
        figli: [f1],
        righe: [rigaAltro],
      );

      // Padre + riga esistente + nuova figlia sotto questo paniere.
      expect(righe, hasLength(3));

      final rigaAltroDopo = righe.firstWhere((r) => r.paniereId == 'altro');
      expect(rigaAltroDopo.qty, 5);
      expect(rigaAltroDopo.prezzo, 30);

      final figlia = righe.firstWhere(
        (r) => r.prodottoId == 'f-1' && r.paniereId == 'p-1',
      );
      expect(figlia.qty, 1);
      expect(figlia.prezzo, 30);
      expect(figlia.paniereNome, 'Pacchetto');
    });
  });
}
