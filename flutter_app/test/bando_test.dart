import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/bando.dart';
import 'package:commerciali_app/data/models/fonte_bando.dart';

void main() {
  group('Bando.fromMap', () {
    test('legge tutti i campi', () {
      final bando = Bando.fromMap({
        'titolo': 'Voucher Digitalizzazione PMI',
        'descrizione': 'Contributo a fondo perduto per software gestionale',
        'data_apertura': '2026-01-15',
        'data_chiusura': '2026-12-31',
        'stato': 'attivo',
        'codici_ateco': ['56', '47'],
        'tutti_ateco': false,
        'regioni': ['lombardia', 'veneto'],
        'tutte_regioni': false,
        'province': ['MI', 'MB'],
        'forma_agevolazione': ['contributo'],
        'dimensioni': ['micro', 'piccola'],
        'settore_attivita': ['ristorazione', 'retail'],
        'obiettivi': ['digitalizzazione'],
        'soggetto_concedente': 'Regione Lombardia',
        'agevolazione_min': 5000,
        'agevolazione_max': 50000,
        'stanziamento': 1000000,
        'link_ufficiale': 'https://example.com/bando',
        'fonte': 'incentivi.gov.it',
        'ultimo_aggiornamento': '2026-06-01',
        'data_importazione': '2026-06-02T10:00:00Z',
      }, id: 'b-1');

      expect(bando.id, 'b-1');
      expect(bando.titolo, 'Voucher Digitalizzazione PMI');
      expect(bando.descrizione, startsWith('Contributo a fondo perduto'));
      expect(bando.dataApertura, '2026-01-15');
      expect(bando.dataChiusura, '2026-12-31');
      expect(bando.stato, 'attivo');
      expect(bando.codiciAteco, ['56', '47']);
      expect(bando.tuttiAteco, isFalse);
      expect(bando.regioni, ['lombardia', 'veneto']);
      expect(bando.tutteRegioni, isFalse);
      expect(bando.province, ['MI', 'MB']);
      expect(bando.formaAgevolazione, ['contributo']);
      expect(bando.dimensioni, ['micro', 'piccola']);
      expect(bando.settoreAttivita, ['ristorazione', 'retail']);
      expect(bando.obiettivi, ['digitalizzazione']);
      expect(bando.soggettoConcedente, 'Regione Lombardia');
      expect(bando.agevolazioneMin, 5000);
      expect(bando.agevolazioneMax, 50000);
      expect(bando.stanziamento, 1000000);
      expect(bando.linkUfficiale, 'https://example.com/bando');
      expect(bando.fonte, 'incentivi.gov.it');
      expect(bando.ultimoAggiornamento, '2026-06-01');
      expect(bando.dataImportazione, '2026-06-02T10:00:00Z');
    });

    test('campi mancanti: stringhe null, liste vuote, booleani false', () {
      final bando = Bando.fromMap({}, id: 'b-1');

      expect(bando.id, 'b-1');
      expect(bando.titolo, isNull);
      expect(bando.descrizione, isNull);
      expect(bando.dataApertura, isNull);
      expect(bando.dataChiusura, isNull);
      expect(bando.stato, isNull);
      expect(bando.codiciAteco, isEmpty);
      expect(bando.tuttiAteco, isFalse);
      expect(bando.regioni, isEmpty);
      expect(bando.tutteRegioni, isFalse);
      expect(bando.province, isEmpty);
      expect(bando.formaAgevolazione, isEmpty);
      expect(bando.dimensioni, isEmpty);
      expect(bando.settoreAttivita, isEmpty);
      expect(bando.obiettivi, isEmpty);
      expect(bando.soggettoConcedente, isNull);
      expect(bando.agevolazioneMin, isNull);
      expect(bando.agevolazioneMax, isNull);
      expect(bando.stanziamento, isNull);
      expect(bando.linkUfficiale, isNull);
      expect(bando.fonte, isNull);
      expect(bando.ultimoAggiornamento, isNull);
      expect(bando.dataImportazione, isNull);
    });

    test('province: lista letta, valore non lista → vuota', () {
      final conProvince = Bando.fromMap({
        'province': ['MI', 'MB'],
      }, id: 'b-1');
      expect(conProvince.province, ['MI', 'MB']);

      final senza = Bando.fromMap({'province': 'MI'}, id: 'b-2');
      expect(senza.province, isEmpty);
    });

    test('booleani veri e agevolazioni numeriche (double) letti correttamente', () {
      final bando = Bando.fromMap({
        'tutti_ateco': true,
        'tutte_regioni': true,
        'agevolazione_max': 50000.0,
      }, id: 'b-2');

      expect(bando.tuttiAteco, isTrue);
      expect(bando.tutteRegioni, isTrue);
      expect(bando.agevolazioneMax, 50000.0);
      expect(bando.agevolazioneMax, isA<num>());
    });

    test('toMap serializza in snake_case senza id', () {
      final bando = Bando(
        id: 'b-1',
        titolo: 'Voucher',
        dataChiusura: '2026-12-31',
        stato: 'attivo',
        codiciAteco: const ['56'],
        tuttiAteco: true,
        province: const ['MI'],
        agevolazioneMax: 50000,
        linkUfficiale: 'https://example.com',
      );

      final map = bando.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['titolo'], 'Voucher');
      expect(map['data_chiusura'], '2026-12-31');
      expect(map['stato'], 'attivo');
      expect(map['codici_ateco'], ['56']);
      expect(map['tutti_ateco'], isTrue);
      expect(map['province'], ['MI']);
      expect(map['agevolazione_max'], 50000);
      expect(map['link_ufficiale'], 'https://example.com');
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = Bando(
        id: 'b-1',
        titolo: 'Voucher',
        dataChiusura: '2026-12-31',
        stato: 'attivo',
        regioni: const ['lombardia'],
        province: const ['MI', 'MB'],
        agevolazioneMax: 50000,
        fonte: 'incentivi.gov.it',
      );

      final ricostruito = Bando.fromMap(
        originale.toMap(),
        id: originale.id,
      );

      expect(ricostruito.titolo, originale.titolo);
      expect(ricostruito.dataChiusura, originale.dataChiusura);
      expect(ricostruito.stato, originale.stato);
      expect(ricostruito.regioni, originale.regioni);
      expect(ricostruito.province, originale.province);
      expect(ricostruito.agevolazioneMax, originale.agevolazioneMax);
      expect(ricostruito.fonte, originale.fonte);
    });
  });

  group('ordinaBandiPerScadenza', () {
    test('ordina per data crescente con i null in fondo', () {
      final bandi = [
        Bando(id: 'a', titolo: 'Senza data', dataChiusura: null),
        Bando(id: 'b', titolo: 'Fine anno', dataChiusura: '2026-12-31'),
        Bando(id: 'c', titolo: 'Prossimo', dataChiusura: '2026-10-31'),
        Bando(id: 'd', titolo: 'Senza data 2', dataChiusura: null),
      ];

      final ordinati = ordinaBandiPerScadenza(bandi);

      expect(
        ordinati.map((b) => b.id).toList(),
        ['c', 'b', 'a', 'd'],
      );
    });

    test('non modifica la lista originale', () {
      final bandi = [
        Bando(id: 'b', dataChiusura: '2026-12-31'),
        Bando(id: 'a', dataChiusura: '2026-01-01'),
      ];

      ordinaBandiPerScadenza(bandi);

      expect(bandi.first.id, 'b');
      expect(bandi.last.id, 'a');
    });
  });

  group('FonteBando.fromMap', () {
    test('legge tutti i campi', () {
      final fonte = FonteBando.fromMap({
        'nome': 'incentivi.gov.it',
        'url': 'https://example.com/feed',
        'tipo': 'json_incentivi',
        'attiva': false,
        'note': 'fonte principale',
        'sync_stato': 'ok',
        'ultimo_sync': '2026-06-02T10:00:00Z',
        'sync_importati': 120,
        'sync_errore': null,
        'updated_at': '2026-06-02T10:00:01Z',
      }, id: 'incentivi_gov');

      expect(fonte.id, 'incentivi_gov');
      expect(fonte.nome, 'incentivi.gov.it');
      expect(fonte.url, 'https://example.com/feed');
      expect(fonte.tipo, 'json_incentivi');
      expect(fonte.attiva, isFalse);
      expect(fonte.note, 'fonte principale');
      expect(fonte.syncStato, 'ok');
      expect(fonte.ultimoSync, '2026-06-02T10:00:00Z');
      expect(fonte.syncImportati, 120);
      expect(fonte.syncErrore, isNull);
      expect(fonte.updatedAt, '2026-06-02T10:00:01Z');
    });

    test('default: tipo rss e attiva true', () {
      final fonte = FonteBando.fromMap({}, id: 'f-1');

      expect(fonte.id, 'f-1');
      expect(fonte.tipo, 'rss');
      expect(fonte.attiva, isTrue);
      expect(fonte.nome, isNull);
      expect(fonte.syncStato, isNull);
      expect(fonte.syncImportati, isNull);
    });

    test('toMap serializza in snake_case senza id', () {
      final fonte = FonteBando(
        id: 'f-1',
        nome: 'incentivi.gov.it',
        tipo: 'json_incentivi',
        attiva: true,
        syncImportati: 120,
      );

      final map = fonte.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['nome'], 'incentivi.gov.it');
      expect(map['tipo'], 'json_incentivi');
      expect(map['attiva'], isTrue);
      expect(map['sync_importati'], 120);
    });
  });
}
