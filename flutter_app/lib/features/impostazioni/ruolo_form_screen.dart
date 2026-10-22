import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/models/ruolo.dart';
import '../../state/azienda_providers.dart';
import 'ruoli_screen.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: livelli di permesso e messaggi in italiano
// ---------------------------------------------------------------------------

/// Livelli di permesso selezionabili, in ordine di tendina.
///
/// La chiave vuota corrisponde a "Nessuno": il servizio scarta le aree senza
/// livello, quindi il ruolo salvato non conserva voci vuote.
const Map<String, String> livelliPermesso = {
  '': 'Nessuno',
  'lettura': 'Sola lettura',
  'scrittura': 'Sola scrittura',
  'entrambi': 'Lettura e scrittura',
};

/// Validazione del nome del ruolo (obbligatorio).
String? validaNomeRuolo(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il nome del ruolo';
  return null;
}

/// Livello di permesso normalizzato: `''` per valori assenti o sconosciuti.
String livelloPermesso(dynamic valore) {
  final testo = (valore?.toString() ?? '').trim().toLowerCase();
  return livelliPermesso.containsKey(testo) ? testo : '';
}

/// Messaggio in italiano per gli errori di salvataggio di un ruolo.
String messaggioErroreSalvataggioRuolo(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per salvare i ruoli. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Salvataggio non riuscito. Riprova.';
    }
  }
  return 'Salvataggio non riuscito. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Form di creazione e modifica di un ruolo dell'azienda attiva.
///
/// Con [ruolo] nullo crea un nuovo ruolo (`inserisciRuolo`), altrimenti
/// aggiorna quello esistente (`aggiornaRuolo`). Non mostra né modifica `chiave`
/// e `sistema`: li gestisce il servizio.
class RuoloFormScreen extends ConsumerStatefulWidget {
  const RuoloFormScreen({super.key, this.ruolo});

  /// Ruolo da modificare; `null` per crearne uno nuovo.
  final Ruolo? ruolo;

  @override
  ConsumerState<RuoloFormScreen> createState() => _RuoloFormScreenState();
}

class _RuoloFormScreenState extends ConsumerState<RuoloFormScreen> {
  final _modulo = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _descrizione;
  late final TextEditingController _sconto;
  late final Map<String, String> _permessi;

  bool _salvando = false;
  String? _errore;

  bool get _modifica => widget.ruolo != null;

  @override
  void initState() {
    super.initState();
    final ruolo = widget.ruolo;
    _nome = TextEditingController(text: ruolo?.nome ?? '');
    _descrizione = TextEditingController(text: ruolo?.descrizione ?? '');
    _sconto = TextEditingController(text: '${ruolo?.scontoMax ?? 0}');
    _permessi = {
      for (final area in etichetteAreePermesso.keys)
        area: livelloPermesso(ruolo?.permessi[area]),
    };
  }

  @override
  void dispose() {
    _nome.dispose();
    _descrizione.dispose();
    _sconto.dispose();
    super.dispose();
  }

  /// Valida, salva sul servizio e chiude la schermata con `true`.
  Future<void> _salva() async {
    final modulo = _modulo.currentState;
    if (modulo == null || !modulo.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _errore = null;
    });

    final sconto = int.tryParse(_sconto.text.trim()) ?? 0;
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final ruolo = widget.ruolo;
      if (ruolo == null) {
        await servizio.inserisciRuolo(
          nome: _nome.text,
          descrizione: _descrizione.text,
          scontoMax: sconto,
          permessi: _permessi,
        );
      } else {
        await servizio.aggiornaRuolo(
          ruolo.id,
          nome: _nome.text,
          descrizione: _descrizione.text,
          scontoMax: sconto,
          permessi: _permessi,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreSalvataggioRuolo(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica ruolo' : 'Nuovo ruolo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpazi.paginaTelefono),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _modulo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'DETTAGLI',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('ruolo-nome'),
                              controller: _nome,
                              enabled: !_salvando,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome *',
                                hintText: 'Es. Commerciale',
                              ),
                              validator: validaNomeRuolo,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('ruolo-descrizione'),
                              controller: _descrizione,
                              enabled: !_salvando,
                              minLines: 2,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                labelText: 'Descrizione',
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('ruolo-sconto'),
                              controller: _sconto,
                              enabled: !_salvando,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Sconto massimo',
                                suffixText: '%',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Permessi per area',
                              style: tema.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpazi.xs),
                            Text(
                              'Scegli il livello di accesso per ogni area. '
                              'Le aree lasciate su "Nessuno" non vengono salvate.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            for (final area in etichetteAreePermesso.keys) ...[
                              DropdownButtonFormField<String>(
                                key: Key('ruolo-permesso-$area'),
                                initialValue: _permessi[area],
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: etichettaAreaPermesso(area),
                                ),
                                items: [
                                  for (final livello in livelliPermesso.entries)
                                    DropdownMenuItem(
                                      value: livello.key,
                                      child: Text(livello.value),
                                    ),
                                ],
                                onChanged: _salvando
                                    ? null
                                    : (valore) => setState(
                                        () => _permessi[area] =
                                            livelloPermesso(valore),
                                      ),
                              ),
                              const SizedBox(height: AppSpazi.s),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('ruolo-errore'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-ruolo'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-ruolo'),
                            onPressed: _salvando ? null : _salva,
                            child: _salvando
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: AppSpazi.s),
                                      Text('Salvataggio…'),
                                    ],
                                  )
                                : Text(
                                    _modifica
                                        ? 'Salva modifiche'
                                        : 'Crea ruolo',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Text(
                      'I campi contrassegnati con * sono obbligatori.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
