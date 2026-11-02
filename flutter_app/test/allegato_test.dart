import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/allegato.dart';

void main() {
  group('Allegato', () {
    test('legge i metadati Firestore', () {
      final allegato = Allegato.fromMap({
        'azienda_id': 'az',
        'elemento_tipo': 'appuntamento',
        'elemento_id': 'a1',
        'nome': 'foto.jpg',
        'tipo_mime': 'image/jpeg',
        'dimensione': 2048,
        'object_key': 'az/a1/key',
        'created_by': 'u1',
        'created_at': '2026-10-24T10:00:00Z',
      }, id: 'all1');

      expect(allegato.id, 'all1');
      expect(allegato.nome, 'foto.jpg');
      expect(allegato.immagine, isTrue);
      expect(allegato.video, isFalse);
      expect(allegato.dimensioneLeggibile, '2 KB');
      expect(allegato.objectKey, 'az/a1/key');
    });

    test('default per documenti vecchi o incompleti', () {
      final allegato = Allegato.fromMap(const {}, id: 'all1');
      expect(allegato.nome, 'Allegato');
      expect(allegato.mime, 'application/octet-stream');
      expect(allegato.elementoTipo, 'appuntamento');
      expect(allegato.dimensione, 0);
    });

    test('riconosce video e dimensione MB', () {
      final allegato = Allegato(
        id: 'all1',
        mime: 'video/mp4',
        dimensione: 3 * 1024 * 1024,
      );
      expect(allegato.video, isTrue);
      expect(allegato.immagine, isFalse);
      expect(allegato.dimensioneLeggibile, '3.0 MB');
    });
  });
}
