import 'package:flutter/material.dart';

/// Menu a tre puntini con le azioni "Modifica" ed "Elimina".
///
/// Usato dalle righe di elenco (card e tabella) di clienti e catalogo. La
/// chiave del widget la passa il chiamante, così ogni riga è individuabile
/// nei test.
class MenuAzioni extends StatelessWidget {
  const MenuAzioni({
    super.key,
    required this.onModifica,
    required this.onElimina,
    this.tooltip = 'Azioni',
  });

  final VoidCallback onModifica;
  final VoidCallback onElimina;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: (azione) {
        if (azione == 'modifica') onModifica();
        if (azione == 'elimina') onElimina();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'modifica', child: Text('Modifica')),
        PopupMenuItem(value: 'elimina', child: Text('Elimina')),
      ],
    );
  }
}
