import 'package:flutter/material.dart';

/// Icona del logo Google "G", con i quattro colori ufficiali.
///
/// Disegnata in locale con un `CustomPainter` (nessun asset né pacchetto
/// esterno), così resta utilizzabile su web e nei test senza dipendenze.
class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

/// Disegna la "G" ufficiale di Google (vista 48×48) scalata sulla misura.
class _GooglePainter extends CustomPainter {
  static const _rosso = Color(0xFFEA4335);
  static const _blu = Color(0xFF4285F4);
  static const _giallo = Color(0xFFFBBC05);
  static const _verde = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final scala = size.width / 48;
    canvas.scale(scala);

    final pennello = Paint()..style = PaintingStyle.fill;

    pennello.color = _rosso;
    canvas.drawPath(_percorsoRosso(), pennello);

    pennello.color = _blu;
    canvas.drawPath(_percorsoBlu(), pennello);

    pennello.color = _giallo;
    canvas.drawPath(_percorsoGiallo(), pennello);

    pennello.color = _verde;
    canvas.drawPath(_percorsoVerde(), pennello);
  }

  Path _percorsoRosso() => Path()
    ..moveTo(24, 9.5)
    ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
    ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
    ..close();

  Path _percorsoBlu() => Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20.0)
    ..lineTo(24, 20.0)
    ..lineTo(24, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
    ..lineTo(39.89, 42.2)
    ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();

  Path _percorsoGiallo() => Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24.0)
    ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24.0)
    ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();

  Path _percorsoVerde() => Path()
    ..moveTo(24, 48)
    ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
    ..close();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
