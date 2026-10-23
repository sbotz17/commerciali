import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('chiaveRuoloDaNome', () {
    test('nomi normali senza spazi', () {
      expect(chiaveRuoloDaNome('Amministratore'), 'amministratore');
      expect(chiaveRuoloDaNome('Commerciale'), 'commerciale');
    });

    test('spazi diventano underscore', () {
      expect(chiaveRuoloDaNome('Gestione Ruoli'), 'gestione_ruoli');
      expect(
        chiaveRuoloDaNome('  Direttore   Vendite  '),
        'direttore_vendite',
      );
    });

    test('accenti e caratteri speciali diventano underscore', () {
      expect(chiaveRuoloDaNome('Ragionière'), 'ragioni_re');
      expect(chiaveRuoloDaNome('Direttore & Vendite'), 'direttore_vendite');
      expect(chiaveRuoloDaNome('A/B'), 'a_b');
      expect(chiaveRuoloDaNome('C++'), 'c');
    });

    test('underscore doppi e iniziali/finali vengono rimossi', () {
      expect(chiaveRuoloDaNome('__Ruolo___Speciale__'), 'ruolo_speciale');
      expect(chiaveRuoloDaNome('_-_Capo_Reparto_-_'), 'capo_reparto');
    });

    test('input vuoto o solo caratteri speciali diventa ruolo', () {
      expect(chiaveRuoloDaNome(''), 'ruolo');
      expect(chiaveRuoloDaNome('   '), 'ruolo');
      expect(chiaveRuoloDaNome('!!!'), 'ruolo');
      expect(chiaveRuoloDaNome('___'), 'ruolo');
    });
  });
}
