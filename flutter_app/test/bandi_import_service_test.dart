import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/services/sp_service.dart';

void main() {
  group('aBlocchi', () {
    test('lista vuota → nessun blocco', () {
      expect(aBlocchi<int>(<int>[], 400), isEmpty);
    });

    test('1 elemento con dimensione 400 → un blocco', () {
      final blocchi = aBlocchi<int>(<int>[1], 400);
      expect(blocchi.length, 1);
      expect(blocchi.first, <int>[1]);
    });

    test('400 elementi → un blocco da 400', () {
      final elementi = List<int>.generate(400, (i) => i);
      final blocchi = aBlocchi<int>(elementi, 400);
      expect(blocchi.length, 1);
      expect(blocchi.first.length, 400);
      expect(blocchi.first.first, 0);
      expect(blocchi.first.last, 399);
    });

    test('401 elementi → due blocchi (400 + 1)', () {
      final elementi = List<int>.generate(401, (i) => i);
      final blocchi = aBlocchi<int>(elementi, 400);
      expect(blocchi.length, 2);
      expect(blocchi[0].length, 400);
      expect(blocchi[1].length, 1);
      expect(blocchi[0].last, 399);
      expect(blocchi[1].first, 400);
    });
  });
}
