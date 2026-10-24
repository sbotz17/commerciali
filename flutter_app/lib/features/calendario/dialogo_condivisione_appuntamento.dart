// Dialogo per condividere un appuntamento con colleghi o gruppi della stessa
// azienda.
//
// Un gruppo è una stanza chat di tipo `gruppo`: selezionarlo aggiunge (o
// toglie) tutti i suoi componenti. Le persone sono comunque selezionabili una
// per una, così il risultato è sempre l'elenco degli uid da invitare.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/stanza_chat.dart';

/// Uid dei componenti del [gruppo] che possono essere invitati.
///
/// Tiene solo le persone presenti in [utenti], quindi membri attivi
/// dell'azienda, ed esclude [escludiUid] (di norma l'utente corrente).
List<String> membriGruppoInvitabili(
  StanzaChat gruppo,
  Map<String, String> utenti, {
  String? escludiUid,
}) {
  final risultato = <String>[];
  for (final uid in gruppo.partecipantiUids) {
    final pulito = uid.trim();
    if (pulito.isEmpty || pulito == escludiUid) continue;
    if (!utenti.containsKey(pulito)) continue;
    if (!risultato.contains(pulito)) risultato.add(pulito);
  }
  return risultato;
}

/// Gruppi con almeno un componente invitabile.
List<StanzaChat> gruppiCondivisibili(
  List<StanzaChat> gruppi,
  Map<String, String> utenti, {
  String? escludiUid,
}) => [
  for (final gruppo in gruppi)
    if (gruppo.tipo == 'gruppo' &&
        membriGruppoInvitabili(
          gruppo,
          utenti,
          escludiUid: escludiUid,
        ).isNotEmpty)
      gruppo,
];

/// Mostra il dialogo e ritorna gli uid scelti, oppure `null` se annullato.
Future<Set<String>?> mostraDialogoCondivisioneAppuntamento(
  BuildContext context, {
  required Map<String, String> utenti,
  required List<StanzaChat> gruppi,
  required Set<String> selezionati,
  String? uidCorrente,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _DialogoCondivisioneAppuntamento(
      utenti: utenti,
      gruppi: gruppi,
      selezionati: selezionati,
      uidCorrente: uidCorrente,
    ),
  );
}

class _DialogoCondivisioneAppuntamento extends StatefulWidget {
  const _DialogoCondivisioneAppuntamento({
    required this.utenti,
    required this.gruppi,
    required this.selezionati,
    this.uidCorrente,
  });

  final Map<String, String> utenti;
  final List<StanzaChat> gruppi;
  final Set<String> selezionati;
  final String? uidCorrente;

  @override
  State<_DialogoCondivisioneAppuntamento> createState() =>
      _DialogoCondivisioneAppuntamentoState();
}

class _DialogoCondivisioneAppuntamentoState
    extends State<_DialogoCondivisioneAppuntamento> {
  late final Set<String> _selezionati = {...widget.selezionati};
  late final List<StanzaChat> _gruppi = gruppiCondivisibili(
    widget.gruppi,
    widget.utenti,
    escludiUid: widget.uidCorrente,
  );
  late final List<String> _utentiOrdinati =
      [
        for (final uid in widget.utenti.keys)
          if (uid != widget.uidCorrente) uid,
      ]..sort(
        (a, b) => (widget.utenti[a] ?? a).toLowerCase().compareTo(
          (widget.utenti[b] ?? b).toLowerCase(),
        ),
      );

  void _toggleUtente(String uid, bool? scelto) {
    setState(() {
      if (scelto == true) {
        _selezionati.add(uid);
      } else {
        _selezionati.remove(uid);
      }
    });
  }

  void _toggleGruppo(StanzaChat gruppo, bool? scelto) {
    final membri = membriGruppoInvitabili(
      gruppo,
      widget.utenti,
      escludiUid: widget.uidCorrente,
    );
    setState(() {
      if (scelto == true) {
        _selezionati.addAll(membri);
      } else {
        _selezionati.removeAll(membri);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      key: const Key('dialogo-condivisione-appuntamento'),
      title: const Text('Condividi appuntamento'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'I colleghi ricevono una notifica e devono confermare la '
                'disponibilità: l\'appuntamento resta in attesa fino alla '
                'prima conferma.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_gruppi.isNotEmpty) ...[
                const SizedBox(height: AppSpazi.m),
                Text(
                  'GRUPPI',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final gruppo in _gruppi) _voceGruppo(gruppo),
              ],
              if (_utentiOrdinati.isNotEmpty) ...[
                const SizedBox(height: AppSpazi.m),
                Text(
                  'PERSONE',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final uid in _utentiOrdinati)
                  CheckboxListTile(
                    key: Key('condivisione-utente-$uid'),
                    value: _selezionati.contains(uid),
                    onChanged: (scelto) => _toggleUtente(uid, scelto),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      widget.utenti[uid] ?? uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              if (_gruppi.isEmpty && _utentiOrdinati.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpazi.m),
                  child: Text(
                    'Nessun collega disponibile da invitare.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('condivisione-annulla'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('condivisione-conferma'),
          onPressed: () => Navigator.of(context).pop({..._selezionati}),
          child: Text(
            _selezionati.isEmpty
                ? 'Conferma'
                : 'Conferma (${_selezionati.length})',
          ),
        ),
      ],
    );
  }

  Widget _voceGruppo(StanzaChat gruppo) {
    final membri = membriGruppoInvitabili(
      gruppo,
      widget.utenti,
      escludiUid: widget.uidCorrente,
    );
    final tuttiScelti =
        membri.isNotEmpty && membri.every(_selezionati.contains);
    final nome = (gruppo.nome ?? '').trim();

    return CheckboxListTile(
      key: Key('condivisione-gruppo-${gruppo.id}'),
      value: tuttiScelti,
      onChanged: (scelto) => _toggleGruppo(gruppo, scelto),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        nome.isEmpty ? 'Gruppo' : nome,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        membri.length == 1 ? '1 componente' : '${membri.length} componenti',
      ),
    );
  }
}
