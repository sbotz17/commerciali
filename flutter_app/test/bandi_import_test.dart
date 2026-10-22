import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/bandi_import.dart';

void main() {
  group('estraiRecordsBandi', () {
    test('array diretto → lista', () {
      final json = [
        {'ID_Incentivo': '1'},
        {'ID_Incentivo': '2'},
      ];
      expect(estraiRecordsBandi(json), json);
    });

    test('risposta Solr {response: {docs: [...]}} → docs', () {
      final docs = [
        {'ID_Incentivo': '1'},
      ];
      final json = {
        'response': {'docs': docs, 'numFound': 1},
      };
      expect(estraiRecordsBandi(json), docs);
    });

    test('oggetto {docs: [...]} → docs', () {
      final docs = [
        {'ID_Incentivo': '1'},
      ];
      expect(estraiRecordsBandi({'docs': docs}), docs);
    });

    test('valore non lista/mappa → lista vuota', () {
      expect(estraiRecordsBandi(null), isEmpty);
      expect(estraiRecordsBandi(42), isEmpty);
      expect(estraiRecordsBandi('testo'), isEmpty);
      expect(estraiRecordsBandi({'altro': true}), isEmpty);
    });
  });

  group('statoBandoDaData', () {
    final adesso = DateTime(2024, 1, 15);

    test('data vuota o assente → permanente', () {
      expect(statoBandoDaData(null, adesso: adesso), 'permanente');
      expect(statoBandoDaData('', adesso: adesso), 'permanente');
      expect(statoBandoDaData('   ', adesso: adesso), 'permanente');
    });

    test('data non valida → permanente', () {
      expect(statoBandoDaData('non-una-data', adesso: adesso), 'permanente');
    });

    test('data passata → scaduto', () {
      expect(
        statoBandoDaData('2024-01-01T00:00:00', adesso: adesso),
        'scaduto',
      );
    });

    test('entro 30 giorni → in_scadenza', () {
      expect(
        statoBandoDaData('2024-01-20T00:00:00', adesso: adesso),
        'in_scadenza',
      );
      // 30 giorni esatti → ancora in scadenza.
      expect(
        statoBandoDaData('2024-02-14T00:00:00', adesso: adesso),
        'in_scadenza',
      );
    });

    test('oltre 30 giorni → attivo', () {
      expect(
        statoBandoDaData('2024-03-01T00:00:00', adesso: adesso),
        'attivo',
      );
      // 31 giorni esatti → attivo.
      expect(
        statoBandoDaData('2024-02-15T00:00:00', adesso: adesso),
        'attivo',
      );
    });
  });

  group('normalizzaBandoIncentivi', () {
    final adesso = DateTime(2024, 1, 15);

    test('normalizzazione completa con ATECO multipli', () {
      final descrizione = List.filled(2500, 'a').join();
      final record = <String, dynamic>{
        'ID_Incentivo': '  1423  ',
        'Titolo': '  Bando di test  ',
        'Descrizione': descrizione,
        'Data_apertura': '2024-01-01T00:00:00',
        'Data_chiusura': '2024-06-01T00:00:00',
        'Codici_ATECO': '01.11; 02.22; 03.33',
        'Regioni': ['Lazio', 'Lombardia'],
        'Forma_agevolazione': ['Contributo'],
        'Dimensioni': ['PMI'],
        'Settore_Attivita': ['Servizi'],
        'Obiettivo_Finalita': ['Internazionalizzazione'],
        'Soggetto_Concedente': '  Lazio Innova  ',
        'Agevolazione_Concedibile_min': '1000',
        'Agevolazione_Concedibile_max': '5000',
        'Stanziamento_incentivo': '1000000',
        'Link_istituzionale': '  https://example.com  ',
        'Data_ultimo_aggiornamento': '2024-01-10T00:00:00',
      };

      final out = normalizzaBandoIncentivi(record, adesso: adesso);

      expect(out['id'], '1423');
      expect(out['titolo'], 'Bando di test');
      expect(out['descrizione'], descrizione.substring(0, 2000));
      expect(out['descrizione'].length, 2000);
      expect(out['data_apertura'], '2024-01-01T00:00:00');
      expect(out['data_chiusura'], '2024-06-01T00:00:00');
      expect(out['stato'], 'attivo');
      expect(out['codici_ateco'], ['01.11', '02.22', '03.33']);
      expect(out['tutti_ateco'], isFalse);
      expect(out['regioni'], ['Lazio', 'Lombardia']);
      expect(out['tutte_regioni'], isFalse);
      expect(out['forma_agevolazione'], ['Contributo']);
      expect(out['dimensioni'], ['PMI']);
      expect(out['settore_attivita'], ['Servizi']);
      expect(out['obiettivi'], ['Internazionalizzazione']);
      expect(out['soggetto_concedente'], 'Lazio Innova');
      expect(out['agevolazione_min'], 1000);
      expect(out['agevolazione_max'], 5000);
      expect(out['stanziamento'], 1000000);
      expect(out['link_ufficiale'], 'https://example.com');
      expect(out['fonte'], 'incentivi.gov.it');
      expect(out['ultimo_aggiornamento'], '2024-01-10T00:00:00');
      expect(out['data_importazione'], adesso.toUtc().toIso8601String());
    });

    test('tutti_ateco quando Codici_ATECO è vuota o "tutti"', () {
      final senza = normalizzaBandoIncentivi(
        {'ID_Incentivo': '1', 'Codici_ATECO': ''},
        adesso: adesso,
      );
      expect(senza['tutti_ateco'], isTrue);
      expect(senza['codici_ateco'], isEmpty);

      final tutti = normalizzaBandoIncentivi(
        {
          'ID_Incentivo': '2',
          'Codici_ATECO': 'Tutti i settori economici ammissibili',
        },
        adesso: adesso,
      );
      expect(tutti['tutti_ateco'], isTrue);
      expect(tutti['codici_ateco'], isEmpty);
    });

    test('tutte_regioni quando Regioni è assente o vuota', () {
      final out = normalizzaBandoIncentivi(
        {'ID_Incentivo': '1'},
        adesso: adesso,
      );
      expect(out['regioni'], isEmpty);
      expect(out['tutte_regioni'], isTrue);
    });

    test('province lette da Province (lista)', () {
      final out = normalizzaBandoIncentivi(
        {'ID_Incentivo': '1', 'Province': ['MI', 'MB']},
        adesso: adesso,
      );
      expect(out['province'], ['MI', 'MB']);
    });

    test('province da Provincia singola e da Comuni', () {
      final singola = normalizzaBandoIncentivi(
        {'ID_Incentivo': '1', 'Provincia': 'MI'},
        adesso: adesso,
      );
      expect(singola['province'], ['MI']);

      final lista = normalizzaBandoIncentivi(
        {'ID_Incentivo': '2', 'Provincia': ['MI', 'MB']},
        adesso: adesso,
      );
      expect(lista['province'], ['MI', 'MB']);

      final comuni = normalizzaBandoIncentivi(
        {'ID_Incentivo': '3', 'Comuni': ['Milano', 'Monza']},
        adesso: adesso,
      );
      expect(comuni['province'], ['Milano', 'Monza']);
    });

    test('id stabile quando manca ID_Incentivo', () {
      final a = normalizzaBandoIncentivi(
        {'Titolo': 'Bando A', 'Link_istituzionale': 'https://a.it'},
        adesso: adesso,
      );
      final b = normalizzaBandoIncentivi(
        {'Titolo': 'Bando A', 'Link_istituzionale': 'https://a.it'},
        adesso: adesso,
      );
      expect(a['id'], b['id']);
      expect(a['id'], startsWith('bando_'));
      expect(a['id'], isNotEmpty);

      // Stesso titolo ma link diverso → id diverso.
      final c = normalizzaBandoIncentivi(
        {'Titolo': 'Bando A', 'Link_istituzionale': 'https://b.it'},
        adesso: adesso,
      );
      expect(c['id'], isNot(a['id']));
    });

    test('campi numerici mancanti → 0', () {
      final out = normalizzaBandoIncentivi(
        {'ID_Incentivo': '1'},
        adesso: adesso,
      );
      expect(out['agevolazione_min'], 0);
      expect(out['agevolazione_max'], 0);
      expect(out['stanziamento'], 0);
    });
  });

  group('normalizzaBandiIncentivi', () {
    final adesso = DateTime(2024, 1, 15);

    test('ignora gli elementi che non sono Map', () {
      final records = <dynamic>[
        {'ID_Incentivo': '1', 'Titolo': 'Primo'},
        'non-una-mappa',
        42,
        null,
        {'ID_Incentivo': '2', 'Titolo': 'Secondo'},
      ];

      final out = normalizzaBandiIncentivi(records, adesso: adesso);

      expect(out.length, 2);
      expect(out[0]['id'], '1');
      expect(out[1]['id'], '2');
    });

    test('lista vuota → lista vuota', () {
      expect(normalizzaBandiIncentivi([], adesso: adesso), isEmpty);
    });
  });
}
