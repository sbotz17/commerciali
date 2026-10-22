import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Dispositivo scelto nella pagina introduttiva.
enum DispositivoIntro { android, iphone, desktop }

/// Pagina introduttiva con le istruzioni per installare Closer come app.
///
/// Funziona sia come primo avvio (dentro `FirstRunGate`) sia come rotta
/// autonoma `/intro`, aperta dalle impostazioni. Il pulsante finale invoca
/// [onFine]: chi la mostra decide cosa fare (salvare il flag o chiudere la
/// pagina).
///
/// Le istruzioni sono animate da Flutter (nessuna GIF da scaricare): funzionano
/// anche offline e si adattano alla larghezza dello schermo.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onFine});

  /// Chiamato al tocco su "Ho capito, inizia".
  final VoidCallback onFine;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  /// Animazione di pulsazione dell'elemento da toccare nel mockup.
  late final AnimationController _controlloPulsazione;

  /// Valore 0–1 che pilota luminosità e alone dell'evidenziazione.
  late final Animation<double> _pulsazione;

  /// Android è la scelta iniziale: è la piattaforma più diffusa tra i clienti.
  DispositivoIntro _dispositivo = DispositivoIntro.android;

  /// Con le animazioni di sistema disattivate la pulsazione resta ferma.
  bool _animazioniRidotte = false;

  @override
  void initState() {
    super.initState();
    _controlloPulsazione = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulsazione = CurvedAnimation(
      parent: _controlloPulsazione,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 0.25, end: 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rispetta l'impostazione "riduci animazioni" del dispositivo.
    final ridotte = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (ridotte == _animazioniRidotte) return;
    _animazioniRidotte = ridotte;
    if (ridotte) {
      _controlloPulsazione
        ..stop()
        ..value = 1;
    } else {
      _controlloPulsazione.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controlloPulsazione.dispose();
    super.dispose();
  }

  void _scegli(DispositivoIntro dispositivo) {
    if (dispositivo == _dispositivo) return;
    setState(() => _dispositivo = dispositivo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // Da rotta autonoma (`/intro`) si può tornare indietro; al primo avvio no.
    final puoChiudere = Navigator.of(context).canPop();

    return Scaffold(
      appBar: puoChiudere
          ? AppBar(title: const Text('Come installare l\'app'))
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const Key('intro-lista'),
              padding: const EdgeInsets.fromLTRB(
                AppSpazi.paginaTelefono,
                AppSpazi.l,
                AppSpazi.paginaTelefono,
                AppSpazi.l,
              ),
              children: [
                Center(
                  child: ClipRRect(
                    key: const Key('intro-icona-app'),
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/icon/closer_icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpazi.m),
                Text(
                  'Installa Closer',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpazi.xs),
                Text(
                  'Puoi usare Closer come un\'app: si apre a tutto schermo '
                  'e la trovi tra le applicazioni del dispositivo. '
                  'Scegli le istruzioni per il tuo dispositivo.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpazi.l),
                _SelettoreDispositivo(
                  scelto: _dispositivo,
                  onScelto: _scegli,
                ),
                const SizedBox(height: AppSpazi.l),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (figlio, animazione) {
                      return FadeTransition(
                        opacity: animazione,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animazione),
                          child: figlio,
                        ),
                      );
                    },
                    child: _pannello(),
                  ),
                ),
                const SizedBox(height: AppSpazi.l),
                FilledButton.icon(
                  key: const Key('intro-ho-capito'),
                  onPressed: widget.onFine,
                  icon: const Icon(Icons.check),
                  label: const Text('Ho capito, inizia'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pannello animato con il mockup e i passi del dispositivo scelto.
  Widget _pannello() {
    switch (_dispositivo) {
      case DispositivoIntro.android:
        return _PannelloIntro(
          key: const Key('intro-suggerimento-android'),
          titolo: 'Android (Chrome)',
          mockup: _MockupAndroid(pulsazione: _pulsazione),
          passi: const [
            'Apri Chrome e tocca il menu ⋮ in alto a destra.',
            'Scegli "Installa app" oppure "Aggiungi a schermata Home".',
            'Conferma: l\'icona di Closer compare tra le app.',
          ],
        );
      case DispositivoIntro.iphone:
        return _PannelloIntro(
          key: const Key('intro-suggerimento-iphone'),
          titolo: 'iPhone e iPad (Safari)',
          mockup: _MockupIphone(pulsazione: _pulsazione),
          passi: const [
            'Apri Closer in Safari e tocca l\'icona Condividi.',
            'Scorri il menu e scegli "Aggiungi a Home".',
            'Conferma con "Aggiungi": l\'icona compare nella schermata Home.',
          ],
        );
      case DispositivoIntro.desktop:
        return _PannelloIntro(
          key: const Key('intro-suggerimento-desktop'),
          titolo: 'Computer (Chrome o Edge)',
          mockup: _MockupDesktop(pulsazione: _pulsazione),
          passi: const [
            'Clicca l\'icona di installazione nella barra degli indirizzi.',
            'Conferma con "Installa".',
            'Closer si apre in una finestra dedicata, come un programma.',
          ],
        );
    }
  }
}

/// Selettore a tre scelte per il tipo di dispositivo.
class _SelettoreDispositivo extends StatelessWidget {
  const _SelettoreDispositivo({required this.scelto, required this.onScelto});

  final DispositivoIntro scelto;
  final ValueChanged<DispositivoIntro> onScelto;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpazi.xs,
      runSpacing: AppSpazi.xs,
      children: [
        _chip(DispositivoIntro.android, 'Android', Icons.android,
            'intro-scelta-android'),
        _chip(DispositivoIntro.iphone, 'iPhone / iPad', Icons.phone_iphone,
            'intro-scelta-iphone'),
        _chip(DispositivoIntro.desktop, 'Computer', Icons.computer,
            'intro-scelta-desktop'),
      ],
    );
  }

  Widget _chip(
    DispositivoIntro dispositivo,
    String etichetta,
    IconData icona,
    String chiave,
  ) {
    return ChoiceChip(
      key: Key(chiave),
      avatar: Icon(icona, size: 18),
      label: Text(etichetta),
      selected: scelto == dispositivo,
      showCheckmark: false,
      onSelected: (_) => onScelto(dispositivo),
    );
  }
}

/// Card con mockup animato, nome della piattaforma e passi per installare.
class _PannelloIntro extends StatelessWidget {
  const _PannelloIntro({
    super.key,
    required this.titolo,
    required this.mockup,
    required this.passi,
  });

  final String titolo;
  final Widget mockup;
  final List<String> passi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ExcludeSemantics(child: mockup)),
            const SizedBox(height: AppSpazi.m),
            Text(titolo, textAlign: TextAlign.center, style: tema.textTheme.titleSmall),
            const SizedBox(height: AppSpazi.s),
            for (var i = 0; i < passi.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpazi.xs),
              _Passo(numero: i + 1, testo: passi[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Riga numerata con un passo delle istruzioni.
class _Passo extends StatelessWidget {
  const _Passo({required this.numero, required this.testo});

  final int numero;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tema.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpazi.xs),
        Expanded(
          child: Text(
            testo,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cornice di un telefono, comune ai mockup Android e iPhone.
class _CorniceTelefono extends StatelessWidget {
  const _CorniceTelefono({required this.figlio});

  static const double larghezza = 220;
  static const double altezza = 340;

  final Widget figlio;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Container(
      width: larghezza,
      height: altezza,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: schema.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: schema.outlineVariant, width: 2),
        boxShadow: [
          BoxShadow(
            color: schema.shadow.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: figlio,
    );
  }
}

/// Mockup Android: menu ⋮ del browser con la voce "Installa app".
class _MockupAndroid extends StatelessWidget {
  const _MockupAndroid({required this.pulsazione});

  final Animation<double> pulsazione;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return _CorniceTelefono(
      figlio: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: schema.surfaceContainerHighest,
            child: Row(
              children: [
                const Expanded(
                  child: _BarraIndirizzoFinta(testo: 'commerciali-app.web.app'),
                ),
                const SizedBox(width: 8),
                _Evidenzia(
                  pulsazione: pulsazione,
                  padding: const EdgeInsets.all(3),
                  raggio: 8,
                  figlio: Icon(Icons.more_vert, size: 16, color: schema.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: _PaginaFinta(),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 168,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: schema.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: schema.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: schema.shadow.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Evidenzia(
                          pulsazione: pulsazione,
                          padding: const EdgeInsets.all(2),
                          raggio: 8,
                          figlio: const _VoceMenuFinta(
                            icona: Icons.download_for_offline_outlined,
                            testo: 'Installa app',
                            evidenziata: true,
                          ),
                        ),
                        const _VoceMenuFinta(
                          icona: Icons.add_to_home_screen,
                          testo: 'Aggiungi a schermata Home',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mockup iPhone/iPad: icona Condividi e voce "Aggiungi a Home".
class _MockupIphone extends StatelessWidget {
  const _MockupIphone({required this.pulsazione});

  final Animation<double> pulsazione;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return _CorniceTelefono(
      figlio: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: schema.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const _BarraIndirizzoFinta(testo: 'commerciali-app.web.app'),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: _PaginaFinta(),
            ),
          ),
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: schema.outlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.chevron_left, size: 16, color: schema.onSurfaceVariant),
                Icon(Icons.chevron_right, size: 16, color: schema.onSurfaceVariant),
                _Evidenzia(
                  pulsazione: pulsazione,
                  padding: const EdgeInsets.all(3),
                  raggio: 8,
                  figlio: Icon(Icons.ios_share, size: 16, color: schema.primary),
                ),
                Icon(Icons.menu_book_outlined, size: 16, color: schema.onSurfaceVariant),
                Icon(Icons.tab_outlined, size: 16, color: schema.onSurfaceVariant),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: schema.surface,
              border: Border(top: BorderSide(color: schema.outlineVariant)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Evidenzia(
                  pulsazione: pulsazione,
                  padding: const EdgeInsets.all(2),
                  raggio: 8,
                  figlio: const _VoceMenuFinta(
                    icona: Icons.add_to_home_screen,
                    testo: 'Aggiungi a Home',
                    evidenziata: true,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: schema.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Aggiungi',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: schema.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mockup desktop: finestra del browser con icona di installazione.
class _MockupDesktop extends StatelessWidget {
  const _MockupDesktop({required this.pulsazione});

  final Animation<double> pulsazione;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final punto = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: schema.outlineVariant,
        shape: BoxShape.circle,
      ),
    );

    return Container(
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: schema.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: schema.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: schema.shadow.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: schema.surfaceContainerHighest,
            child: Row(
              children: [
                punto,
                const SizedBox(width: 4),
                punto,
                const SizedBox(width: 4),
                punto,
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: schema.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: schema.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 11,
                          color: schema.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'commerciali-app.web.app',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: schema.onSurfaceVariant,
                            ),
                          ),
                        ),
                        _Evidenzia(
                          pulsazione: pulsazione,
                          padding: const EdgeInsets.all(2),
                          raggio: 6,
                          figlio: Icon(
                            Icons.install_desktop,
                            size: 14,
                            color: schema.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.more_vert,
                  size: 14,
                  color: schema.onSurfaceVariant,
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: _PaginaFinta(),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 172,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: schema.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: schema.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: schema.shadow.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Installa Closer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: schema.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: schema.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Installa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: schema.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pillola che imita la barra degli indirizzi dei browser mobili.
class _BarraIndirizzoFinta extends StatelessWidget {
  const _BarraIndirizzoFinta({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: schema.surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        testo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 8, color: schema.onSurfaceVariant),
      ),
    );
  }
}

/// Contenuto finto della pagina web dentro i mockup.
class _PaginaFinta extends StatelessWidget {
  const _PaginaFinta();

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final riga = BoxDecoration(
      color: schema.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 90,
          height: 12,
          decoration: BoxDecoration(
            color: schema.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 10),
        for (final larghezza in <double>[150, 130, 140, 100]) ...[
          Container(width: larghezza, height: 7, decoration: riga),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// Voce di un menu finto: icona più etichetta.
class _VoceMenuFinta extends StatelessWidget {
  const _VoceMenuFinta({
    required this.icona,
    required this.testo,
    this.evidenziata = false,
  });

  final IconData icona;
  final String testo;
  final bool evidenziata;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        children: [
          Icon(
            icona,
            size: 14,
            color: evidenziata ? schema.primary : schema.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              testo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.2,
                fontWeight: evidenziata ? FontWeight.w700 : FontWeight.w500,
                color: evidenziata ? schema.primary : schema.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Evidenzia un elemento del mockup con alone e luminosità pulsanti.
class _Evidenzia extends StatelessWidget {
  const _Evidenzia({
    required this.pulsazione,
    required this.figlio,
    this.raggio = 10,
    this.padding = const EdgeInsets.all(2),
  });

  final Animation<double> pulsazione;
  final Widget figlio;
  final double raggio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: pulsazione,
      builder: (context, child) {
        final t = pulsazione.value;
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: schema.primaryContainer.withValues(alpha: 0.30 + 0.60 * t),
            borderRadius: BorderRadius.circular(raggio),
            boxShadow: [
              BoxShadow(
                color: schema.primary.withValues(alpha: 0.28 * t),
                blurRadius: 10 * t,
                spreadRadius: 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: figlio,
    );
  }
}
