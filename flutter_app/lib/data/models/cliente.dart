/// Cliente come vive nella collezione Firestore `clienti`.
///
/// I nomi dei campi Firestore sono snake_case ([tipo_cliente],
/// [codice_fiscale], [azienda_id]); il modello li espone in camelCase
/// ([tipoCliente], [codiceFiscale], [aziendaId]) come convenzione Dart/Flutter.
class Cliente {
  const Cliente({
    required this.id,
    this.aziendaId,
    this.tipoCliente = 'azienda',
    this.nome,
    this.referente,
    this.email,
    this.telefono,
    this.piva,
    this.codiceFiscale,
    this.indirizzo,
    this.civico,
    this.cap,
    this.citta,
    this.provincia,
    this.ateco,
    this.settore,
    this.regione,
    this.note,
  });

  /// Crea un cliente dal documento Firestore. [id] è l'id del documento.
  factory Cliente.fromMap(Map<String, dynamic> map, {required String id}) {
    return Cliente(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      tipoCliente: (map['tipo_cliente'] as String?) ?? 'azienda',
      nome: map['nome'] as String?,
      referente: map['referente'] as String?,
      email: map['email'] as String?,
      telefono: map['telefono'] as String?,
      piva: map['piva'] as String?,
      codiceFiscale: map['codice_fiscale'] as String?,
      indirizzo: map['indirizzo'] as String?,
      civico: map['civico'] as String?,
      cap: map['cap'] as String?,
      citta: map['citta'] as String?,
      provincia: map['provincia'] as String?,
      ateco: map['ateco'] as String?,
      settore: map['settore'] as String?,
      regione: map['regione'] as String?,
      note: map['note'] as String?,
    );
  }

  /// Id del documento `clienti`.
  final String id;

  /// Id dell'azienda a cui appartiene (campo Firestore `azienda_id`).
  final String? aziendaId;

  /// Tipologia (`azienda`, `privato`, ...). Campo Firestore `tipo_cliente`.
  final String tipoCliente;

  final String? nome;
  final String? referente;
  final String? email;
  final String? telefono;
  final String? piva;
  final String? codiceFiscale;
  final String? indirizzo;
  final String? civico;
  final String? cap;
  final String? citta;
  final String? provincia;
  final String? ateco;
  final String? settore;
  final String? regione;
  final String? note;

  /// Serializza verso i campi Firestore (snake_case), escluso [id] che è la
  /// chiave documento.
  Map<String, dynamic> toMap() => {
        'azienda_id': aziendaId,
        'tipo_cliente': tipoCliente,
        'nome': nome,
        'referente': referente,
        'email': email,
        'telefono': telefono,
        'piva': piva,
        'codice_fiscale': codiceFiscale,
        'indirizzo': indirizzo,
        'civico': civico,
        'cap': cap,
        'citta': citta,
        'provincia': provincia,
        'ateco': ateco,
        'settore': settore,
        'regione': regione,
        'note': note,
      };
}

/// Normalizza una Partita IVA: maiuscola, senza prefisso `IT`, senza spazi.
///
/// Ritorna `null` se il valore è vuoto o assente (così una P.IVA "vuota" non
/// viene mai usata nei confronti di duplicati).
String? normalizzaPiva(String? value) {
  if (value == null) return null;
  var p = value.trim().toUpperCase();
  if (p.startsWith('IT')) p = p.substring(2);
  p = p.trim();
  return p.isEmpty ? null : p;
}

/// Verifica se [candidato] è già presente tra [altri].
///
/// Confronto in cascata, come la vecchia app: prima la P.IVA (normalizzata,
/// ignorando spazi e prefisso `IT`), poi il nome esatto (case-insensitive),
/// poi il codice fiscale (case-insensitive). Ritorna il primo cliente
/// corrispondente o `null` se non esiste un duplicato.
Cliente? clienteDuplicato(Cliente candidato, List<Cliente> altri) {
  final piva = normalizzaPiva(candidato.piva);
  if (piva != null) {
    for (final c in altri) {
      final cp = normalizzaPiva(c.piva);
      if (cp != null && cp == piva) return c;
    }
  }

  final nome = candidato.nome?.trim().toLowerCase();
  if (nome != null && nome.isNotEmpty) {
    for (final c in altri) {
      final cn = (c.nome ?? '').trim().toLowerCase();
      if (cn.isNotEmpty && cn == nome) return c;
    }
  }

  final cf = candidato.codiceFiscale?.trim().toLowerCase();
  if (cf != null && cf.isNotEmpty) {
    for (final c in altri) {
      final ccf = (c.codiceFiscale ?? '').trim().toLowerCase();
      if (ccf.isNotEmpty && ccf == cf) return c;
    }
  }

  return null;
}

/// Eccezione lanciata quando un cliente risulta già presente (duplicato).
class DuplicatoClienteException implements Exception {
  DuplicatoClienteException([this.message = 'Cliente già esistente']);

  final String message;

  @override
  String toString() => 'DuplicatoClienteException: $message';
}
