import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/user_profile.dart';

void main() {
  group('UserProfile.fromMap', () {
    test('legge super_admin true', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
        'super_admin': true,
      }, id: 'uid-1');

      expect(profile.id, 'uid-1');
      expect(profile.uid, 'uid-1');
      expect(profile.superAdmin, isTrue);
    });

    test('legge super_admin false esplicito', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
        'super_admin': false,
      }, id: 'uid-1');

      expect(profile.superAdmin, isFalse);
    });

    test('super_admin assente vale false', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
      }, id: 'uid-1');

      expect(profile.superAdmin, isFalse);
    });

    test('legge attivo false', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
        'attivo': false,
      }, id: 'uid-1');

      expect(profile.attivo, isFalse);
    });

    test('legge attivo true', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
        'attivo': true,
      }, id: 'uid-1');

      expect(profile.attivo, isTrue);
    });

    test('attivo assente vale null', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
      }, id: 'uid-1');

      expect(profile.attivo, isNull);
    });

    test('legge uid esplicito quando presente', () {
      final profile = UserProfile.fromMap({
        'email': 'anna@example.it',
        'uid': 'uid-esplicito',
      }, id: 'uid-doc');

      expect(profile.id, 'uid-doc');
      expect(profile.uid, 'uid-esplicito');
    });
  });
}
