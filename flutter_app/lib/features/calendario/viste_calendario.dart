// Viste classiche del calendario: mese, settimana e giorno.
//
// Le viste sono widget senza provider: ricevono le voci già caricate e le
// callback per il dettaglio, la creazione su uno spazio vuoto e il passaggio al
// giorno. Restano così verificabili con widget test senza Firebase.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../visite/visite_screen.dart' show dataIsoVisita, formattaDataVisita;
import 'calendario_logica.dart';

/// Vista mensile classica: griglia lunedì–domenica con le voci di ogni giorno.
class VistaMeseCalendario extends StatelessWidget {
  const VistaMeseCalendario({
    super.key,
    required this.mese,
    required this.elementi,
    this.onTapVoce,
    this.onTapGiorno,
  });

  /// Mese da mostrare (il giorno non conta).
  final DateTime mese;

  /// Voci dell'agenda; quelle di altri mesi restano visibili nelle celle
  /// iniziali e finali, in tono attenuato.
  final List<ElementoAgenda> elementi;

  /// Apertura del dettaglio di una voce.
  final ValueChanged<ElementoAgenda>? onTapVoce;

  /// Passaggio al giorno selezionato (per esempio alla vista giorno).
  final ValueChanged<DateTime>? onTapGiorno;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compatto = constraints.maxWidth < AppBreakpoints.telefono;
        final giorni = giorniGrigliaMese(mese);
        final gruppi = raggruppaPerGiorno(elementi);
        final settimane = giorni.length ~/ 7;
        final altezzaDisponibile = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : settimane * 96.0;
        final altezzaCella = ((altezzaDisponibile - 32) / settimane)
            .clamp(64.0, 150.0)
            .toDouble();
        final massimoVoci = compatto
            ? 0
            : ((altezzaCella - 34) / 20).floor().clamp(0, 4);

        final griglia = SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpazi.xs),
          child: Column(
            children: [
              for (var settimana = 0; settimana < settimane; settimana++)
                SizedBox(
                  height: altezzaCella,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var indice = 0; indice < 7; indice++)
                        Expanded(
                          child: _CellaMese(
                            giorno: giorni[settimana * 7 + indice],
                            mese: mese,
                            voci:
                                gruppi[dataIsoVisita(
                                  giorni[settimana * 7 + indice],
                                )] ??
                                const <ElementoAgenda>[],
                            compatto: compatto,
                            massimoVoci: massimoVoci,
                            onTapVoce: onTapVoce,
                            onTapGiorno: onTapGiorno,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

        return Column(
          key: const Key('calendario-mese'),
          mainAxisSize: constraints.hasBoundedHeight
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  for (var indice = 0; indice < 7; indice++)
                    Expanded(
                      child: Center(
                        child: Text(
                          nomiGiorniBrevi[indice].toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (constraints.hasBoundedHeight)
              Expanded(child: griglia)
            else
              griglia,
          ],
        );
      },
    );
  }
}

/// Singola cella della griglia mensile.
class _CellaMese extends StatelessWidget {
  const _CellaMese({
    required this.giorno,
    required this.mese,
    required this.voci,
    required this.compatto,
    required this.massimoVoci,
    this.onTapVoce,
    this.onTapGiorno,
  });

  final DateTime giorno;
  final DateTime mese;
  final List<ElementoAgenda> voci;
  final bool compatto;
  final int massimoVoci;
  final ValueChanged<ElementoAgenda>? onTapVoce;
  final ValueChanged<DateTime>? onTapGiorno;

  bool get _oggi {
    final ora = DateTime.now();
    return giorno.year == ora.year &&
        giorno.month == ora.month &&
        giorno.day == ora.day;
  }

  bool get _fuoriMese => giorno.month != mese.month || giorno.year != mese.year;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final coloreGiorno = _fuoriMese
        ? tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
        : tema.colorScheme.onSurface;

    return Material(
      color: _fuoriMese ? AppColors.sfondo : AppColors.superficie,
      child: InkWell(
        onTap: onTapGiorno == null ? null : () => onTapGiorno!(giorno),
        hoverColor: AppColors.primario.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: AppColors.bordo),
              bottom: BorderSide(color: AppColors.bordo),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: _oggi
                        ? const BoxDecoration(
                            color: AppColors.primario,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      '${giorno.day}',
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: _oggi ? Colors.white : coloreGiorno,
                        fontWeight: _oggi ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (compatto)
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final voce in voci.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: coloreStatoElemento(voce),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final voce in voci.take(massimoVoci))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _ChipMese(elemento: voce, onTap: onTapVoce),
                        ),
                      if (voci.length > massimoVoci)
                        Text(
                          '+${voci.length - massimoVoci}',
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Piccola voce nella cella del mese: ora e titolo.
class _ChipMese extends StatelessWidget {
  const _ChipMese({required this.elemento, this.onTap});

  final ElementoAgenda elemento;
  final ValueChanged<ElementoAgenda>? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoElemento(elemento);
    final ora = elemento.ora;

    return Material(
      color: colore.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRaggi.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(elemento),
        child: SizedBox(
          height: 18,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                if (ora != null) ...[
                  Text(
                    ora,
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: colore,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                if (elemento.appuntamento?.inAttesaDiConferma == true) ...[
                  const Icon(
                    Icons.hourglass_top,
                    size: 9,
                    color: AppColors.attesa,
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: Text(
                    elemento.titolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: colore,
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista giorno/settimana classica: righello delle ore e colonne dei giorni.
class VistaGrigliaOraria extends StatelessWidget {
  const VistaGrigliaOraria({
    super.key,
    required this.giorni,
    required this.elementi,
    this.nomiOperatori = const {},
    this.onTapVoce,
    this.onTapVuoto,
    this.onTapGiorno,
  });

  /// Giorni da mostrare: uno per la vista giorno, sette per la settimana.
  final List<DateTime> giorni;

  /// Voci dell'agenda (anche di altri periodi: vengono filtrate).
  final List<ElementoAgenda> elementi;

  /// Nomi degli operatori per il dettaglio delle card.
  final Map<String, String> nomiOperatori;

  /// Apertura del dettaglio di una voce.
  final ValueChanged<ElementoAgenda>? onTapVoce;

  /// Tocco su uno spazio vuoto: giorno e ora `HH:MM` proposti.
  final void Function(DateTime giorno, String ora)? onTapVuoto;

  /// Passaggio al giorno selezionato.
  final ValueChanged<DateTime>? onTapGiorno;

  @override
  Widget build(BuildContext context) {
    final chiavi = {for (final giorno in giorni) dataIsoVisita(giorno)};
    final vociPeriodo = [
      for (final elemento in elementi)
        if (chiavi.contains(elemento.data.trim())) elemento,
    ];
    final gruppi = raggruppaPerGiorno(vociPeriodo);
    final intervallo = intervalloOrarioElementi(vociPeriodo);
    final senzaOrario = vociSenzaOrario(vociPeriodo);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compatto = constraints.maxWidth < AppBreakpoints.telefono;
        final altezzaOra = compatto ? 48.0 : 56.0;
        const larghezzaOra = 56.0;
        final larghezzaGiorno = giorni.length == 1
            ? (constraints.maxWidth - larghezzaOra).clamp(160.0, 10000.0)
            : ((constraints.maxWidth - larghezzaOra) / giorni.length).clamp(
                120.0,
                10000.0,
              );
        final larghezzaTotale = larghezzaOra + larghezzaGiorno * giorni.length;
        final altezzaGriglia =
            ((intervallo.fine - intervallo.inizio) / 60) * altezzaOra;

        final corpo = SingleChildScrollView(
          child: SizedBox(
            height: altezzaGriglia,
            child: _GrigliaOraria(
              giorni: giorni,
              gruppi: gruppi,
              intervallo: intervallo,
              altezzaOra: altezzaOra,
              larghezzaOra: larghezzaOra,
              larghezzaGiorno: larghezzaGiorno,
              nomiOperatori: nomiOperatori,
              onTapVoce: onTapVoce,
              onTapVuoto: onTapVuoto,
            ),
          ),
        );

        final contenuto = SizedBox(
          width: larghezzaTotale,
          child: Column(
            mainAxisSize: constraints.hasBoundedHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              _IntestazioneGiorni(
                giorni: giorni,
                larghezzaOra: larghezzaOra,
                larghezzaGiorno: larghezzaGiorno,
                onTapGiorno: onTapGiorno,
              ),
              if (constraints.hasBoundedHeight)
                Expanded(child: corpo)
              else
                corpo,
              if (senzaOrario.isNotEmpty)
                _BarraSenzaOrario(voci: senzaOrario, onTapVoce: onTapVoce),
            ],
          ),
        );

        return SingleChildScrollView(
          key: Key(
            giorni.length == 1
                ? 'calendario-griglia-giorno'
                : 'calendario-griglia-settimana',
          ),
          scrollDirection: Axis.horizontal,
          child: contenuto,
        );
      },
    );
  }
}

/// Intestazione con i nomi dei giorni e il numero.
class _IntestazioneGiorni extends StatelessWidget {
  const _IntestazioneGiorni({
    required this.giorni,
    required this.larghezzaOra,
    required this.larghezzaGiorno,
    this.onTapGiorno,
  });

  final List<DateTime> giorni;
  final double larghezzaOra;
  final double larghezzaGiorno;
  final ValueChanged<DateTime>? onTapGiorno;

  bool _oggi(DateTime giorno) {
    final ora = DateTime.now();
    return giorno.year == ora.year &&
        giorno.month == ora.month &&
        giorno.day == ora.day;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final singolo = giorni.length == 1;

    return SizedBox(
      height: singolo ? 68 : 52,
      child: Row(
        children: [
          SizedBox(width: larghezzaOra),
          for (final giorno in giorni)
            SizedBox(
              width: larghezzaGiorno,
              child: Material(
                color: _oggi(giorno)
                    ? AppColors.primario.withValues(alpha: 0.06)
                    : Colors.transparent,
                child: InkWell(
                  onTap: onTapGiorno == null
                      ? null
                      : () => onTapGiorno!(giorno),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpazi.xxs,
                      horizontal: AppSpazi.xs,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          singolo
                              ? nomiGiorni[giorno.weekday - 1]
                              : nomiGiorniBrevi[giorno.weekday - 1]
                                    .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: _oggi(giorno)
                                ? AppColors.primario
                                : tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: _oggi(giorno)
                              ? const BoxDecoration(
                                  color: AppColors.primario,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Text(
                            '${giorno.day}',
                            style: tema.textTheme.titleSmall?.copyWith(
                              color: _oggi(giorno)
                                  ? Colors.white
                                  : tema.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (singolo)
                          Text(
                            formattaDataVisita(giorno),
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Griglia con righello delle ore, colonne dei giorni ed eventi posizionati.
class _GrigliaOraria extends StatelessWidget {
  const _GrigliaOraria({
    required this.giorni,
    required this.gruppi,
    required this.intervallo,
    required this.altezzaOra,
    required this.larghezzaOra,
    required this.larghezzaGiorno,
    required this.nomiOperatori,
    this.onTapVoce,
    this.onTapVuoto,
  });

  final List<DateTime> giorni;
  final Map<String, List<ElementoAgenda>> gruppi;
  final ({int inizio, int fine}) intervallo;
  final double altezzaOra;
  final double larghezzaOra;
  final double larghezzaGiorno;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTapVoce;
  final void Function(DateTime giorno, String ora)? onTapVuoto;

  bool _oggi(DateTime giorno) {
    final ora = DateTime.now();
    return giorno.year == ora.year &&
        giorno.month == ora.month &&
        giorno.day == ora.day;
  }

  /// Ora `HH:MM` arrotondata alla mezz'ora dal punto toccato.
  String _oraDaPosizione(double y) {
    final minuti = intervallo.inizio + (y / altezzaOra * 60);
    final massimo = (intervallo.fine - 30).clamp(intervallo.inizio, 24 * 60);
    final slot = (minuti / 30).floor() * 30;
    final limitato = slot.clamp(intervallo.inizio, massimo);
    final ore = limitato ~/ 60;
    final resto = limitato % 60;
    return '${ore.toString().padLeft(2, '0')}:'
        '${resto.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ore = <int>[];
    for (
      var minuto = intervallo.inizio;
      minuto <= intervallo.fine;
      minuto += 60
    ) {
      ore.add(minuto);
    }

    return Stack(
      children: [
        // Sfondo delle colonne (evidenzia oggi).
        for (var indice = 0; indice < giorni.length; indice++)
          Positioned(
            left: larghezzaOra + indice * larghezzaGiorno,
            top: 0,
            width: larghezzaGiorno,
            height: (intervallo.fine - intervallo.inizio) / 60 * altezzaOra,
            child: IgnorePointer(
              child: Container(
                color: _oggi(giorni[indice])
                    ? AppColors.primario.withValues(alpha: 0.035)
                    : Colors.transparent,
              ),
            ),
          ),
        // Righe delle ore e righello.
        for (final minuto in ore)
          Positioned(
            left: 0,
            right: 0,
            top: (minuto - intervallo.inizio) / 60 * altezzaOra,
            child: IgnorePointer(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: larghezzaOra,
                    child: Transform.translate(
                      offset: const Offset(0, -6),
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpazi.xs),
                        child: Text(
                          '${(minuto ~/ 60).toString().padLeft(2, '0')}:00',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: AppColors.bordo)),
                ],
              ),
            ),
          ),
        // Separatori verticali delle colonne.
        for (var indice = 0; indice <= giorni.length; indice++)
          Positioned(
            left: larghezzaOra + indice * larghezzaGiorno,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(width: 1, color: AppColors.bordo),
            ),
          ),
        // Aree vuote cliccabili: creano un appuntamento all'ora toccata.
        for (var indice = 0; indice < giorni.length; indice++)
          Positioned(
            left: larghezzaOra + indice * larghezzaGiorno,
            top: 0,
            width: larghezzaGiorno,
            height: (intervallo.fine - intervallo.inizio) / 60 * altezzaOra,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onTapVuoto == null
                  ? null
                  : (dettagli) => onTapVuoto!(
                      giorni[indice],
                      _oraDaPosizione(dettagli.localPosition.dy),
                    ),
            ),
          ),
        // Eventi posizionati sopra lo sfondo.
        for (var indice = 0; indice < giorni.length; indice++)
          for (final voce in disponiVociGiorno(
            gruppi[dataIsoVisita(giorni[indice])] ?? const <ElementoAgenda>[],
          ))
            Positioned(
              left:
                  larghezzaOra +
                  indice * larghezzaGiorno +
                  (voce.corsia / voce.corsie) * larghezzaGiorno +
                  2,
              top: (voce.inizio - intervallo.inizio) / 60 * altezzaOra + 1,
              width: (larghezzaGiorno / voce.corsie - 4).clamp(24.0, 10000.0),
              height: ((voce.fine - voce.inizio) / 60 * altezzaOra - 2).clamp(
                22.0,
                10000.0,
              ),
              child: _EventoGriglia(
                voce: voce,
                nomiOperatori: nomiOperatori,
                onTap: onTapVoce,
              ),
            ),
      ],
    );
  }
}

/// Card di un evento dentro la griglia oraria.
class _EventoGriglia extends StatelessWidget {
  const _EventoGriglia({
    required this.voce,
    required this.nomiOperatori,
    this.onTap,
  });

  final VocePosizionata voce;
  final Map<String, String> nomiOperatori;
  final ValueChanged<ElementoAgenda>? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoElemento(voce.elemento);
    final dettaglio = dettaglioElemento(voce.elemento, nomiOperatori);

    return Material(
      color: colore.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRaggi.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(voce.elemento),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colore, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final altezza = constraints.maxHeight;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (altezza >= 14)
                    Row(
                      children: [
                        Icon(
                          voce.elemento.isAppuntamento
                              ? Icons.event_outlined
                              : Icons.task_alt_outlined,
                          size: 12,
                          color: colore,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            voce.elemento.ora ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: colore,
                              fontSize: 10,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (voce.elemento.appuntamento?.inAttesaDiConferma ==
                            true)
                          const Icon(
                            Icons.hourglass_top,
                            size: 10,
                            color: AppColors.attesa,
                          ),
                      ],
                    ),
                  if (altezza >= 32)
                    Text(
                      voce.elemento.titolo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.labelMedium?.copyWith(
                        color: tema.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (altezza >= 44)
                    Text(
                      dettaglio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Barra in fondo con le voci che non hanno un orario.
class _BarraSenzaOrario extends StatelessWidget {
  const _BarraSenzaOrario({required this.voci, this.onTapVoce});

  final List<ElementoAgenda> voci;
  final ValueChanged<ElementoAgenda>? onTapVoce;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      key: const Key('calendario-senza-orario'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpazi.xs, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.sfondo,
        border: Border(top: BorderSide(color: AppColors.bordo)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              'Senza\norario',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final voce in voci) ...[
                    _ChipSenzaOrario(elemento: voce, onTap: onTapVoce),
                    const SizedBox(width: AppSpazi.xs),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip di una voce senza orario.
class _ChipSenzaOrario extends StatelessWidget {
  const _ChipSenzaOrario({required this.elemento, this.onTap});

  final ElementoAgenda elemento;
  final ValueChanged<ElementoAgenda>? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoElemento(elemento);

    return Material(
      color: colore.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRaggi.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(elemento),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                elemento.isAppuntamento
                    ? Icons.event_outlined
                    : Icons.task_alt_outlined,
                size: 12,
                color: colore,
              ),
              const SizedBox(width: 4),
              Text(
                elemento.titolo,
                style: tema.textTheme.labelMedium?.copyWith(color: colore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
