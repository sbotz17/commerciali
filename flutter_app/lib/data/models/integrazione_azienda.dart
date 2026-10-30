// Modelli delle integrazioni di calendario di un'azienda.
//
// I campi dei documenti Firestore sono snake_case (`client_id`,
// `secret_ref`, `call_predefinita`); i modelli li espongono in camelCase
// ([clientId], [secretRef], [callPredefinita]) come convenzione Dart/Flutter.
//
// Per sicurezza questi modelli NON contengono mai campi `client_secret` o
// token: il segreto è un riferimento ([ConfigIntegrazioneProvider.secretRef])
// e i token di accesso/refresh vivono fuori da questi modelli.

/// Livelli di condivisione del calendario ammessi.
///
/// Ordine crescente di visibilità: `libero_occupato` mostra solo la
/// disponibilità, `dettagli` i dettagli degli eventi, `modifica` consente
/// anche la modifica.
const List<String> livelliCondivisione = [
  'libero_occupato',
  'dettagli',
  'modifica',
];

/// Etichetta leggibile per un livello di condivisione, con fallback.
String etichettaLivelloCondivisione(String? livello) {
  const etichette = {
    'libero_occupato': 'Solo libero/occupato',
    'dettagli': 'Dettagli evento',
    'modifica': 'Modifica',
  };
  final s = livello?.trim();
  if (s == null || s.isEmpty) return 'Sconosciuto';
  return etichette[s] ?? s;
}

/// Configurazione di un singolo provider (Google o Microsoft) per
/// l'integrazione del calendario.
///
/// Vive come sotto-mappa dentro il documento `integrazioni_azienda/{aziendaId}`.
class ConfigIntegrazioneProvider {
  ConfigIntegrazioneProvider({
    this.modalita = 'closer',
    this.attivo = false,
    this.clientId,
    this.secretRef,
    this.redirectUri,
    this.tenantId,
    this.stato = 'non_configurata',
    this.configuratoDa,
    this.configuratoAt,
    this.ultimoTestAt,
    this.errore,
  });

  /// Legge la configurazione da una mappa Firestore. Valori mancanti o
  /// non validi ricadono sui default.
  factory ConfigIntegrazioneProvider.fromMap(Map<String, dynamic> map) {
    return ConfigIntegrazioneProvider(
      modalita: _normalizzaModalita(map['modalita'] as String?),
      attivo: map['attivo'] == true,
      clientId: map['client_id'] as String?,
      secretRef: map['secret_ref'] as String?,
      redirectUri: map['redirect_uri'] as String?,
      tenantId: map['tenant_id'] as String?,
      stato: _normalizzaStato(map['stato'] as String?),
      configuratoDa: map['configurato_da'] as String?,
      configuratoAt: map['configurato_at'] as String?,
      ultimoTestAt: map['ultimo_test_at'] as String?,
      errore: map['errore'] as String?,
    );
  }

  /// Modalità dell'integrazione (`closer` usa le credenziali della piattaforma
  /// Closer, `personalizzata` quelle dell'azienda). Campo `modalita`, default
  /// `closer`.
  final String modalita;

  /// Se l'integrazione di questo provider è attiva (campo `attivo`).
  final bool attivo;

  /// Client id OAuth del provider (campo `client_id`).
  final String? clientId;

  /// Riferimento al segreto (es. nome della risorsa in un vault); NON è il
  /// segreto stesso (campo `secret_ref`).
  final String? secretRef;

  /// URI di redirect OAuth (campo `redirect_uri`).
  final String? redirectUri;

  /// Tenant id, presente solo per Microsoft (campo `tenant_id`).
  final String? tenantId;

  /// Stato della configurazione (`non_configurata`, `configurata`, `errore`,
  /// `da_rinnovare`). Campo `stato`, default `non_configurata`.
  final String stato;

  /// Uid dell'utente che ha configurato il provider (campo `configurato_da`).
  final String? configuratoDa;

  /// Timestamp di configurazione ISO-8601 (campo `configurato_at`).
  final String? configuratoAt;

  /// Timestamp dell'ultimo test riuscito ISO-8601 (campo `ultimo_test_at`).
  final String? ultimoTestAt;

  /// Descrizione dell'ultimo errore, `null` se assente (campo `errore`).
  final String? errore;

  /// Restituisce una copia con i campi indicati modificati.
  ///
  /// I campi non passati mantengono il valore corrente. Per azzerare un campo
  /// passare esplicitamente `null`.
  ConfigIntegrazioneProvider copyWith({
    String? modalita,
    bool? attivo,
    Object? clientId = _sentinel,
    Object? secretRef = _sentinel,
    Object? redirectUri = _sentinel,
    Object? tenantId = _sentinel,
    String? stato,
    Object? configuratoDa = _sentinel,
    Object? configuratoAt = _sentinel,
    Object? ultimoTestAt = _sentinel,
    Object? errore = _sentinel,
  }) {
    return ConfigIntegrazioneProvider(
      modalita: modalita ?? this.modalita,
      attivo: attivo ?? this.attivo,
      clientId: clientId == _sentinel ? this.clientId : clientId as String?,
      secretRef: secretRef == _sentinel ? this.secretRef : secretRef as String?,
      redirectUri:
          redirectUri == _sentinel ? this.redirectUri : redirectUri as String?,
      tenantId: tenantId == _sentinel ? this.tenantId : tenantId as String?,
      stato: stato ?? this.stato,
      configuratoDa:
          configuratoDa == _sentinel ? this.configuratoDa : configuratoDa as String?,
      configuratoAt:
          configuratoAt == _sentinel ? this.configuratoAt : configuratoAt as String?,
      ultimoTestAt:
          ultimoTestAt == _sentinel ? this.ultimoTestAt : ultimoTestAt as String?,
      errore: errore == _sentinel ? this.errore : errore as String?,
    );
  }

  /// Serializza verso i campi Firestore (snake_case). Non contiene mai
  /// `client_secret` né token.
  Map<String, dynamic> toMap() => {
        'modalita': modalita,
        'attivo': attivo,
        'client_id': clientId,
        'secret_ref': secretRef,
        'redirect_uri': redirectUri,
        'tenant_id': tenantId,
        'stato': stato,
        'configurato_da': configuratoDa,
        'configurato_at': configuratoAt,
        'ultimo_test_at': ultimoTestAt,
        'errore': errore,
      };
}

/// Integrazione calendario di un'azienda, come vive nel documento Firestore
/// `integrazioni_azienda/{aziendaId}`.
class IntegrazioneAzienda {
  const IntegrazioneAzienda({
    required this.aziendaId,
    this.google,
    this.microsoft,
    this.callPredefinita = 'meet',
    this.condivisioneAbilitata = true,
    this.livelloCondivisionePredefinito = 'dettagli',
    this.updatedAt,
  });

  /// Legge un'integrazione dalla mappa Firestore. [id] è l'id del documento
  /// `integrazioni_azienda` e viene usato come [aziendaId].
  factory IntegrazioneAzienda.fromMap(Map<String, dynamic> map,
      {required String id}) {
    return IntegrazioneAzienda(
      aziendaId: id,
      google: map['google'] is Map<String, dynamic>
          ? ConfigIntegrazioneProvider.fromMap(
              Map<String, dynamic>.from(map['google'] as Map))
          : null,
      microsoft: map['microsoft'] is Map<String, dynamic>
          ? ConfigIntegrazioneProvider.fromMap(
              Map<String, dynamic>.from(map['microsoft'] as Map))
          : null,
      callPredefinita:
          _normalizzaCallPredefinita(map['call_predefinita'] as String?),
      condivisioneAbilitata:
          (map['condivisione_abilitata'] as bool?) ?? true,
      livelloCondivisionePredefinito: _normalizzaLivello(
          map['livello_condivisione_predefinito'] as String?),
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// Crea un'integrazione vuota (default) per l'azienda [aziendaId].
  factory IntegrazioneAzienda.vuota(String aziendaId) =>
      IntegrazioneAzienda(aziendaId: aziendaId);

  /// Id dell'azienda a cui appartiene l'integrazione (id del documento).
  final String aziendaId;

  /// Configurazione del provider Google, `null` se assente.
  final ConfigIntegrazioneProvider? google;

  /// Configurazione del provider Microsoft, `null` se assente.
  final ConfigIntegrazioneProvider? microsoft;

  /// Provider predefinito per le call (`meet` o `teams`). Campo
  /// `call_predefinita`, default `meet`.
  final String callPredefinita;

  /// Se la condivisione del calendario è abilitata (campo
  /// `condivisione_abilitata`), default `true`.
  final bool condivisioneAbilitata;

  /// Livello di condivisione predefinito per i nuovi collegamenti (campo
  /// `livello_condivisione_predefinito`), default `dettagli`.
  final String livelloCondivisionePredefinito;

  /// Timestamp di ultima modifica ISO-8601 (campo `updated_at`).
  final String? updatedAt;

  /// Restituisce una copia con i campi indicati modificati. I campi non
  /// passati mantengono il valore corrente; per azzerare un campo passare
  /// esplicitamente `null`.
  IntegrazioneAzienda copyWith({
    String? aziendaId,
    Object? google = _sentinel,
    Object? microsoft = _sentinel,
    String? callPredefinita,
    bool? condivisioneAbilitata,
    String? livelloCondivisionePredefinito,
    Object? updatedAt = _sentinel,
  }) {
    return IntegrazioneAzienda(
      aziendaId: aziendaId ?? this.aziendaId,
      google: google == _sentinel
          ? this.google
          : google as ConfigIntegrazioneProvider?,
      microsoft: microsoft == _sentinel
          ? this.microsoft
          : microsoft as ConfigIntegrazioneProvider?,
      callPredefinita: callPredefinita ?? this.callPredefinita,
      condivisioneAbilitata: condivisioneAbilitata ?? this.condivisioneAbilitata,
      livelloCondivisionePredefinito:
          livelloCondivisionePredefinito ?? this.livelloCondivisionePredefinito,
      updatedAt: updatedAt == _sentinel ? this.updatedAt : updatedAt as String?,
    );
  }

  /// Serializza verso i campi Firestore (snake_case), escluso [aziendaId] che
  /// è la chiave documento.
  Map<String, dynamic> toMap() => {
        'google': google?.toMap(),
        'microsoft': microsoft?.toMap(),
        'call_predefinita': callPredefinita,
        'condivisione_abilitata': condivisioneAbilitata,
        'livello_condivisione_predefinito': livelloCondivisionePredefinito,
        'updated_at': updatedAt,
      };
}

/// Valori ammessi per la modalità di un provider.
const Set<String> _modalitaValide = {'closer', 'personalizzata'};

/// Valori ammessi per lo stato di una configurazione.
const Set<String> _statiConfigValidi = {
  'non_configurata',
  'configurata',
  'errore',
  'da_rinnovare',
};

/// Valori ammessi per la call predefinita.
const Set<String> _callPredefiniteValide = {'meet', 'teams'};

/// Valori ammessi per il livello di condivisione.
const Set<String> _livelliValidi = {
  'libero_occupato',
  'dettagli',
  'modifica',
};

/// Ritorna la modalità se valida, altrimenti il default `closer`.
String _normalizzaModalita(String? valore) =>
    _modalitaValide.contains(valore) ? valore! : 'closer';

/// Ritorna lo stato se valido, altrimenti il default `non_configurata`.
String _normalizzaStato(String? valore) =>
    _statiConfigValidi.contains(valore) ? valore! : 'non_configurata';

/// Ritorna la call predefinita se valida, altrimenti il default `meet`.
String _normalizzaCallPredefinita(String? valore) =>
    _callPredefiniteValide.contains(valore) ? valore! : 'meet';

/// Ritorna il livello se valido, altrimenti il default `dettagli`.
String _normalizzaLivello(String? valore) =>
    _livelliValidi.contains(valore) ? valore! : 'dettagli';

/// Sentinel usata da [copyWith] per distinguere "campo non passato" da
/// "campo da azzerare a `null`".
const Object _sentinel = Object();
