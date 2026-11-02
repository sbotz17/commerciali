/// Metadati di un allegato collegato a un appuntamento o a un task.
///
/// Il file vero è conservato nel KV del Worker Cloudflare (`ALLEGATI`); qui
/// vivono solo i metadati letti da Firestore.
class Allegato {
  const Allegato({
    required this.id,
    this.aziendaId,
    this.elementoTipo = 'appuntamento',
    this.elementoId,
    this.nome = 'Allegato',
    this.mime = 'application/octet-stream',
    this.dimensione = 0,
    this.objectKey,
    this.createdBy,
    this.createdAt,
  });

  factory Allegato.fromMap(Map<String, dynamic> map, {required String id}) {
    return Allegato(
      id: id,
      aziendaId: map['azienda_id'] as String?,
      elementoTipo: (map['elemento_tipo'] as String?) ?? 'appuntamento',
      elementoId: map['elemento_id'] as String?,
      nome: (map['nome'] as String?) ?? 'Allegato',
      mime: (map['tipo_mime'] as String?) ?? 'application/octet-stream',
      dimensione: (map['dimensione'] as num?)?.toInt() ?? 0,
      objectKey: map['object_key'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  final String id;
  final String? aziendaId;
  final String elementoTipo;
  final String? elementoId;
  final String nome;
  final String mime;
  final int dimensione;
  final String? objectKey;
  final String? createdBy;
  final String? createdAt;

  bool get immagine => mime.startsWith('image/');
  bool get video => mime.startsWith('video/');

  String get dimensioneLeggibile {
    if (dimensione >= 1024 * 1024) {
      return '${(dimensione / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (dimensione >= 1024) {
      return '${(dimensione / 1024).round()} KB';
    }
    return '$dimensione B';
  }
}
