// Modello del task (attività da fare) dell'agenda.
//
// La classe si chiama `TaskItem` per evitare il conflitto con `Task` di
// altri namespace/package Dart. I campi del documento Firestore sono
// snake_case (`scadenza_data`, `scadenza_ora`, `completato_at`); il modello
// li espone in camelCase ([scadenzaData], [scadenzaOra], [completatoAt])
// come convenzione Dart/Flutter.

/// Task come vive nella collezione Firestore `tasks`.
///
/// I nomi dei campi Firestore sono snake_case; il modello li espone in
/// camelCase come convenzione Dart/Flutter.
class TaskItem {
  const TaskItem({
    required this.id,
    this.aziendaId,
    this.titolo,
    this.descrizione,
    this.scadenzaData,
    this.scadenzaOra,
    this.operatoreId,
    this.priorita = 'normale',
    this.stato = 'aperto',
    this.clienteId,
    this.clienteNome,
    this.appuntamentoId,
    this.note,
    this.completatoDa,
    this.completatoAt,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Crea un task dal documento Firestore. [id] è l'id del documento.
  factory TaskItem.fromMap(Map<String, dynamic> map, {required String id}) {
    return TaskItem(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      titolo: map['titolo'] as String?,
      descrizione: map['descrizione'] as String?,
      scadenzaData: map['scadenza_data'] as String?,
      scadenzaOra: map['scadenza_ora'] as String?,
      operatoreId: map['operatore_id'] as String?,
      priorita: (map['priorita'] as String?) ?? 'normale',
      stato: (map['stato'] as String?) ?? 'aperto',
      clienteId: map['cliente_id'] as String?,
      clienteNome: map['cliente_nome'] as String?,
      appuntamentoId: map['appuntamento_id'] as String?,
      note: map['note'] as String?,
      completatoDa: map['completato_da'] as String?,
      completatoAt: map['completato_at'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// Id del documento `tasks`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Titolo del task (campo `titolo`).
  final String? titolo;

  /// Descrizione (campo `descrizione`).
  final String? descrizione;

  /// Data di scadenza `YYYY-MM-DD` (campo `scadenza_data`).
  final String? scadenzaData;

  /// Ora di scadenza `HH:MM` (campo `scadenza_ora`).
  final String? scadenzaOra;

  /// Id dell'operatore assegnato (campo `operatore_id`).
  final String? operatoreId;

  /// Priorità (`normale`, `urgente`). Campo `priorita`, default `normale`.
  final String priorita;

  /// Stato (`aperto`, `completato`). Campo `stato`, default `aperto`.
  final String stato;

  /// Id del cliente collegato (campo `cliente_id`).
  final String? clienteId;

  /// Nome del cliente denormalizzato (campo `cliente_nome`).
  final String? clienteNome;

  /// Id dell'appuntamento collegato (campo `appuntamento_id`).
  final String? appuntamentoId;

  /// Note libere (campo `note`).
  final String? note;

  /// Id dell'utente che ha completato il task (campo `completato_da`).
  final String? completatoDa;

  /// Timestamp di completamento ISO-8601 (campo `completato_at`).
  final String? completatoAt;

  /// Id dell'utente che ha creato il record (campo `created_by`).
  final String? createdBy;

  /// Timestamp di creazione ISO-8601 (campo `created_at`).
  final String? createdAt;

  /// Timestamp di ultima modifica ISO-8601 (campo `updated_at`).
  final String? updatedAt;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'titolo': titolo,
        'descrizione': descrizione,
        'scadenza_data': scadenzaData,
        'scadenza_ora': scadenzaOra,
        'operatore_id': operatoreId,
        'priorita': priorita,
        'stato': stato,
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'appuntamento_id': appuntamentoId,
        'note': note,
        'completato_da': completatoDa,
        'completato_at': completatoAt,
        'created_by': createdBy,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// Combina [scadenzaData] (`YYYY-MM-DD`) e [scadenzaOra] (`HH:MM`) in un
/// [DateTime].
///
/// Ritorna `null` se una delle due è assente, non rispetta il formato o
/// rappresenta una data/ora non valida (es. `2026-02-30` o `25:00`).
DateTime? dataOraTask(TaskItem t) => _combinaDataOra(t.scadenzaData, t.scadenzaOra);

/// Etichetta leggibile per la priorità di un task, con fallback.
String etichettaPrioritaTask(String? priorita) {
  const etichette = {
    'normale': 'Normale',
    'urgente': 'Urgente',
  };
  final p = priorita?.trim();
  if (p == null || p.isEmpty) return 'Non definita';
  return etichette[p] ?? p;
}

DateTime? _combinaDataOra(String? data, String? ora) {
  if (data == null || ora == null) return null;
  final dataMatch =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(data.trim());
  final oraMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(ora.trim());
  if (dataMatch == null || oraMatch == null) return null;

  final anno = int.tryParse(dataMatch.group(1)!);
  final mese = int.tryParse(dataMatch.group(2)!);
  final giorno = int.tryParse(dataMatch.group(3)!);
  final ore = int.tryParse(oraMatch.group(1)!);
  final minuti = int.tryParse(oraMatch.group(2)!);
  if (anno == null ||
      mese == null ||
      giorno == null ||
      ore == null ||
      minuti == null) {
    return null;
  }

  final dt = DateTime(anno, mese, giorno, ore, minuti);
  if (dt.year != anno ||
      dt.month != mese ||
      dt.day != giorno ||
      dt.hour != ore ||
      dt.minute != minuti) {
    return null;
  }
  return dt;
}
