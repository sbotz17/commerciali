import 'package:flutter_test/flutter_test.dart';

import 'package:commerciali_app/data/models/condivisione_calendario.dart';
import 'package:commerciali_app/data/models/integrazione_azienda.dart';

void main() {
  group('ConfigIntegrazioneProvider', () {
    test('default per mappa vuota', () {
      final c = ConfigIntegrazioneProvider.fromMap({});

      expect(c.modalita, 'closer');
      expect(c.attivo, isFalse);
      expect(c.clientId, isNull);
      expect(c.secretRef, isNull);
      expect(c.redirectUri, isNull);
      expect(c.tenantId, isNull);
      expect(c.stato, 'non_configurata');
      expect(c.configuratoDa, isNull);
      expect(c.configuratoAt, isNull);
      expect(c.ultimoTestAt, isNull);
      expect(c.errore, isNull);
    });

    test('parsing completo', () {
      final c = ConfigIntegrazioneProvider.fromMap({
        'modalita': 'personalizzata',
        'attivo': true,
        'client_id': 'client-123',
        'secret_ref': 'projects/p/secrets/ms-client-secret',
        'redirect_uri': 'https://app.example.com/oauth',
        'tenant_id': 'tenant-guid',
        'stato': 'configurata',
        'configurato_da': 'u-1',
        'configurato_at': '2026-10-01T10:00:00Z',
        'ultimo_test_at': '2026-10-02T10:00:00Z',
        'errore': 'timeout',
      });

      expect(c.modalita, 'personalizzata');
      expect(c.attivo, isTrue);
      expect(c.clientId, 'client-123');
      expect(c.secretRef, 'projects/p/secrets/ms-client-secret');
      expect(c.redirectUri, 'https://app.example.com/oauth');
      expect(c.tenantId, 'tenant-guid');
      expect(c.stato, 'configurata');
      expect(c.configuratoDa, 'u-1');
      expect(c.configuratoAt, '2026-10-01T10:00:00Z');
      expect(c.ultimoTestAt, '2026-10-02T10:00:00Z');
      expect(c.errore, 'timeout');
    });

    test('valori non validi ricadono sui default', () {
      final c = ConfigIntegrazioneProvider.fromMap({
        'modalita': 'boh',
        'stato': 'strano',
      });
      expect(c.modalita, 'closer');
      expect(c.stato, 'non_configurata');
    });

    test('toMap serializza snake_case e senza campi segreti', () {
      final c = ConfigIntegrazioneProvider.fromMap({
        'modalita': 'personalizzata',
        'attivo': true,
        'client_id': 'client-123',
        'secret_ref': 'projects/p/secrets/x',
        'redirect_uri': 'https://app.example.com/oauth',
        'tenant_id': 'tenant-guid',
        'stato': 'configurata',
        'configurato_da': 'u-1',
        'configurato_at': '2026-10-01T10:00:00Z',
        'ultimo_test_at': '2026-10-02T10:00:00Z',
        'errore': 'timeout',
      });

      final map = c.toMap();

      expect(map['modalita'], 'personalizzata');
      expect(map['attivo'], isTrue);
      expect(map['client_id'], 'client-123');
      expect(map['secret_ref'], 'projects/p/secrets/x');
      expect(map['redirect_uri'], 'https://app.example.com/oauth');
      expect(map['tenant_id'], 'tenant-guid');
      expect(map['stato'], 'configurata');
      expect(map['configurato_da'], 'u-1');
      expect(map['configurato_at'], '2026-10-01T10:00:00Z');
      expect(map['ultimo_test_at'], '2026-10-02T10:00:00Z');
      expect(map['errore'], 'timeout');

      expect(map.containsKey('client_secret'), isFalse);
      expect(map.containsKey('token'), isFalse);
      expect(map.containsKey('refresh_token'), isFalse);
    });

    test('copyWith modifica i campi e azzera i nullable', () {
      final c = ConfigIntegrazioneProvider(
        modalita: 'closer',
        attivo: false,
        clientId: 'client-1',
        secretRef: 's-1',
        redirectUri: 'https://r',
        tenantId: 't-1',
        stato: 'non_configurata',
        configuratoDa: 'u-1',
        configuratoAt: '2026-10-01',
        ultimoTestAt: '2026-10-02',
        errore: 'e',
      );

      final modified = c.copyWith(attivo: true, stato: 'configurata');
      expect(modified.attivo, isTrue);
      expect(modified.stato, 'configurata');
      // campi non passati invariati
      expect(modified.clientId, 'client-1');
      expect(modified.secretRef, 's-1');
      expect(modified.errore, 'e');

      final azzerato = c.copyWith(clientId: null, errore: null);
      expect(azzerato.clientId, isNull);
      expect(azzerato.errore, isNull);
      expect(azzerato.tenantId, 't-1');
    });
  });

  group('IntegrazioneAzienda', () {
    test('default per mappa vuota e vuota(aziendaId)', () {
      final i = IntegrazioneAzienda.fromMap({}, id: 'az-1');

      expect(i.aziendaId, 'az-1');
      expect(i.google, isNull);
      expect(i.microsoft, isNull);
      expect(i.callPredefinita, 'meet');
      expect(i.condivisioneAbilitata, isTrue);
      expect(i.livelloCondivisionePredefinito, 'dettagli');
      expect(i.updatedAt, isNull);

      final v = IntegrazioneAzienda.vuota('az-2');
      expect(v.aziendaId, 'az-2');
      expect(v.callPredefinita, 'meet');
      expect(v.condivisioneAbilitata, isTrue);
      expect(v.livelloCondivisionePredefinito, 'dettagli');
      expect(v.google, isNull);
      expect(v.microsoft, isNull);
    });

    test('parsing completo con provider annidati', () {
      final i = IntegrazioneAzienda.fromMap({
        'google': {
          'modalita': 'closer',
          'attivo': true,
          'client_id': 'g-client',
          'secret_ref': 'g-secret',
          'stato': 'configurata',
        },
        'microsoft': {
          'modalita': 'personalizzata',
          'attivo': false,
          'client_id': 'm-client',
          'tenant_id': 'm-tenant',
          'stato': 'da_rinnovare',
        },
        'call_predefinita': 'teams',
        'condivisione_abilitata': false,
        'livello_condivisione_predefinito': 'modifica',
        'updated_at': '2026-10-03T10:00:00Z',
      }, id: 'az-1');

      expect(i.aziendaId, 'az-1');
      expect(i.google, isNotNull);
      expect(i.google!.clientId, 'g-client');
      expect(i.google!.attivo, isTrue);
      expect(i.microsoft, isNotNull);
      expect(i.microsoft!.clientId, 'm-client');
      expect(i.microsoft!.tenantId, 'm-tenant');
      expect(i.microsoft!.stato, 'da_rinnovare');
      expect(i.callPredefinita, 'teams');
      expect(i.condivisioneAbilitata, isFalse);
      expect(i.livelloCondivisionePredefinito, 'modifica');
      expect(i.updatedAt, '2026-10-03T10:00:00Z');
    });

    test('valori non validi ricadono sui default', () {
      final i = IntegrazioneAzienda.fromMap({
        'call_predefinita': 'zoom',
        'livello_condivisione_predefinito': 'tutto',
      }, id: 'az-1');
      expect(i.callPredefinita, 'meet');
      expect(i.livelloCondivisionePredefinito, 'dettagli');
    });

    test('toMap serializza senza campi segreti anche negli annidati', () {
      final i = IntegrazioneAzienda(
        aziendaId: 'az-1',
        google: ConfigIntegrazioneProvider(
          modalita: 'closer',
          attivo: true,
          clientId: 'g-client',
          secretRef: 'g-secret',
          redirectUri: 'https://r',
        ),
        microsoft: ConfigIntegrazioneProvider(
          modalita: 'personalizzata',
          clientId: 'm-client',
          tenantId: 'm-tenant',
        ),
        callPredefinita: 'teams',
        condivisioneAbilitata: true,
        livelloCondivisionePredefinito: 'modifica',
        updatedAt: '2026-10-03T10:00:00Z',
      );

      final map = i.toMap();

      expect(map.containsKey('azienda_id'), isFalse);
      expect(map['call_predefinita'], 'teams');
      expect(map['condivisione_abilitata'], isTrue);
      expect(map['livello_condivisione_predefinito'], 'modifica');
      expect(map['updated_at'], '2026-10-03T10:00:00Z');

      final google = map['google'] as Map<String, dynamic>;
      final microsoft = map['microsoft'] as Map<String, dynamic>;
      expect(google['client_id'], 'g-client');
      expect(google['secret_ref'], 'g-secret');
      expect(microsoft['tenant_id'], 'm-tenant');

      for (final m in [map, google, microsoft]) {
        expect(m.containsKey('client_secret'), isFalse);
        expect(m.containsKey('token'), isFalse);
        expect(m.containsKey('refresh_token'), isFalse);
      }
    });

    test('round-trip fromMap(toMap(...)) conserva i valori', () {
      final originale = IntegrazioneAzienda(
        aziendaId: 'az-1',
        google: ConfigIntegrazioneProvider(
          modalita: 'closer',
          attivo: true,
          clientId: 'g-client',
          secretRef: 'g-secret',
          redirectUri: 'https://r',
          stato: 'configurata',
          configuratoDa: 'u-1',
          configuratoAt: '2026-10-01',
          ultimoTestAt: '2026-10-02',
        ),
        callPredefinita: 'teams',
        condivisioneAbilitata: false,
        livelloCondivisionePredefinito: 'modifica',
        updatedAt: '2026-10-03T10:00:00Z',
      );

      final ricostruito =
          IntegrazioneAzienda.fromMap(originale.toMap(), id: originale.aziendaId);

      expect(ricostruito.aziendaId, originale.aziendaId);
      expect(ricostruito.google, isNotNull);
      expect(ricostruito.google!.clientId, 'g-client');
      expect(ricostruito.google!.secretRef, 'g-secret');
      expect(ricostruito.google!.stato, 'configurata');
      expect(ricostruito.callPredefinita, 'teams');
      expect(ricostruito.condivisioneAbilitata, isFalse);
      expect(ricostruito.livelloCondivisionePredefinito, 'modifica');
      expect(ricostruito.updatedAt, '2026-10-03T10:00:00Z');
    });

    test('copyWith modifica i campi e azzera i nullable', () {
      final i = IntegrazioneAzienda(
        aziendaId: 'az-1',
        callPredefinita: 'meet',
        condivisioneAbilitata: true,
        livelloCondivisionePredefinito: 'dettagli',
        updatedAt: '2026-10-01',
      );

      final modified = i.copyWith(
        callPredefinita: 'teams',
        condivisioneAbilitata: false,
        livelloCondivisionePredefinito: 'modifica',
      );
      expect(modified.callPredefinita, 'teams');
      expect(modified.condivisioneAbilitata, isFalse);
      expect(modified.livelloCondivisionePredefinito, 'modifica');
      expect(modified.updatedAt, '2026-10-01');

      final azzerato = i.copyWith(updatedAt: null);
      expect(azzerato.updatedAt, isNull);
      expect(azzerato.aziendaId, 'az-1');
    });
  });

  group('CondivisioneCalendario', () {
    test('default livello dettagli e stato attiva', () {
      final c = CondivisioneCalendario(id: 's-1');
      expect(c.livello, 'dettagli');
      expect(c.stato, 'attiva');
      expect(c.attiva, isTrue);
      expect(c.aziendaId, isNull);
      expect(c.proprietarioUid, isNull);
      expect(c.destinatarioUid, isNull);
    });

    test('parsing completo', () {
      final c = CondivisioneCalendario.fromMap({
        'azienda_id': 'az-1',
        'proprietario_uid': 'u-1',
        'destinatario_uid': 'u-2',
        'livello': 'modifica',
        'stato': 'revocata',
        'creato_da': 'u-1',
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-02T10:00:00Z',
        'revoked_at': '2026-10-03T10:00:00Z',
        'revoked_by': 'u-1',
      }, id: 's-1');

      expect(c.id, 's-1');
      expect(c.aziendaId, 'az-1');
      expect(c.proprietarioUid, 'u-1');
      expect(c.destinatarioUid, 'u-2');
      expect(c.livello, 'modifica');
      expect(c.stato, 'revocata');
      expect(c.attiva, isFalse);
      expect(c.creatoDa, 'u-1');
      expect(c.createdAt, '2026-10-01T10:00:00Z');
      expect(c.updatedAt, '2026-10-02T10:00:00Z');
      expect(c.revokedAt, '2026-10-03T10:00:00Z');
      expect(c.revokedBy, 'u-1');
    });

    test('livello/stato non validi ricadono sui default', () {
      final c = CondivisioneCalendario(
        id: 's-1',
        livello: 'tutto',
        stato: 'boh',
      );
      expect(c.livello, 'dettagli');
      expect(c.stato, 'attiva');

      final fromMap = CondivisioneCalendario.fromMap({
        'livello': 'tutto',
        'stato': 'boh',
      }, id: 's-2');
      expect(fromMap.livello, 'dettagli');
      expect(fromMap.stato, 'attiva');
    });

    test('idPer compone aziendaId_proprietarioUid_destinatarioUid', () {
      expect(
        CondivisioneCalendario.idPer(
          aziendaId: 'az-1',
          proprietarioUid: 'u-1',
          destinatarioUid: 'u-2',
        ),
        'az-1_u-1_u-2',
      );
    });

    test('etichettaLivello usa le etichette dei livelli', () {
      expect(
        CondivisioneCalendario(id: 's-1', livello: 'libero_occupato')
            .etichettaLivello,
        'Solo libero/occupato',
      );
      expect(
        CondivisioneCalendario(id: 's-1', livello: 'dettagli').etichettaLivello,
        'Dettagli evento',
      );
      expect(
        CondivisioneCalendario(id: 's-1', livello: 'modifica').etichettaLivello,
        'Modifica',
      );
    });

    test('toMap serializza snake_case senza id', () {
      final c = CondivisioneCalendario(
        id: 's-1',
        aziendaId: 'az-1',
        proprietarioUid: 'u-1',
        destinatarioUid: 'u-2',
        livello: 'modifica',
        stato: 'revocata',
        creatoDa: 'u-1',
        createdAt: '2026-10-01T10:00:00Z',
        updatedAt: '2026-10-02T10:00:00Z',
        revokedAt: '2026-10-03T10:00:00Z',
        revokedBy: 'u-1',
      );

      final map = c.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['azienda_id'], 'az-1');
      expect(map['proprietario_uid'], 'u-1');
      expect(map['destinatario_uid'], 'u-2');
      expect(map['livello'], 'modifica');
      expect(map['stato'], 'revocata');
      expect(map['creato_da'], 'u-1');
      expect(map['created_at'], '2026-10-01T10:00:00Z');
      expect(map['updated_at'], '2026-10-02T10:00:00Z');
      expect(map['revoked_at'], '2026-10-03T10:00:00Z');
      expect(map['revoked_by'], 'u-1');
    });

    test('copyWith modifica i campi e azzera i nullable', () {
      final c = CondivisioneCalendario(
        id: 's-1',
        aziendaId: 'az-1',
        proprietarioUid: 'u-1',
        destinatarioUid: 'u-2',
        livello: 'dettagli',
        stato: 'attiva',
        revokedAt: '2026-10-03',
      );

      final modified = c.copyWith(livello: 'modifica', stato: 'revocata');
      expect(modified.livello, 'modifica');
      expect(modified.stato, 'revocata');
      expect(modified.attiva, isFalse);
      expect(modified.revokedAt, '2026-10-03');

      final azzerato = c.copyWith(revokedAt: null, revokedBy: 'u-1');
      expect(azzerato.revokedAt, isNull);
      expect(azzerato.revokedBy, 'u-1');
      expect(azzerato.aziendaId, 'az-1');
    });
  });

  group('livelli ed etichette', () {
    test('livelliCondivisione contiene i tre livelli attesi', () {
      expect(livelliCondivisione, containsAll(['libero_occupato', 'dettagli', 'modifica']));
    });

    test('etichettaLivelloCondivisione traduce e fa fallback', () {
      expect(etichettaLivelloCondivisione('libero_occupato'), 'Solo libero/occupato');
      expect(etichettaLivelloCondivisione('dettagli'), 'Dettagli evento');
      expect(etichettaLivelloCondivisione('modifica'), 'Modifica');
      expect(etichettaLivelloCondivisione(null), 'Sconosciuto');
      expect(etichettaLivelloCondivisione(''), 'Sconosciuto');
      expect(etichettaLivelloCondivisione('altro'), 'altro');
    });
  });
}
