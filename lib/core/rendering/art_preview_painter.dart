import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import '../models/pixel_art.dart';

/// Paints a static preview of a [PixelArt] from its grid data — artworks have
/// no thumbnail files. Ported from the app's gallery preview painter
/// (home_screen.dart) plus the gem cell rendering (pixel_grid.dart) so admin
/// previews match what each flavor's users see.
///
/// [gemStyle] renders each cell as a faceted "drill" (Gem Art flavor);
/// otherwise cells are flat squares batched into one drawRawPoints call per
/// color — a 128x128 preview is otherwise ~16k draw ops.
/// [dimmed] renders the app's not-yet-completed look (translucent colors).
class ArtPreviewPainter extends CustomPainter {
  final PixelArt art;
  final bool dimmed;
  final bool gemStyle;

  ArtPreviewPainter({
    required this.art,
    this.dimmed = false,
    this.gemStyle = false,
  });

  // Gem rendering tuning — mirrors the app's pixel_grid.dart constants.
  static const double _gemRingWidth = 0.18;
  static const double _gemRingRadius = 0.9;
  static const double _gemHighlightOffset = 0.35;
  static const int _gemHighlightCoreAlpha = 160;
  static const int _gemHighlightHaloAlpha = 90;

  @override
  void paint(Canvas canvas, Size size) {
    if (gemStyle) {
      _paintGems(canvas, size);
    } else {
      _paintFlat(canvas, size);
    }
  }

  void _paintFlat(Canvas canvas, Size size) {
    final cw = size.width / art.gridWidth;
    final ch = size.height / art.gridHeight;

    final batches = <int, List<double>>{};
    for (var r = 0; r < art.gridHeight; r++) {
      for (var c = 0; c < art.gridWidth; c++) {
        final val = art.grid[r][c];
        if (val <= 0) continue;
        final color = art.colorForNumber(val) ?? const Color(0x00000000);
        final key = (dimmed ? color.withAlpha(90) : color).toARGB32();
        batches.putIfAbsent(key, () => <double>[])
          ..add(c * cw + cw / 2)
          ..add(r * ch + ch / 2);
      }
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.square
      ..strokeWidth = max(cw, ch);
    for (final entry in batches.entries) {
      paint.color = Color(entry.key);
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList(entry.value),
        paint,
      );
    }
  }

  void _paintGems(Canvas canvas, Size size) {
    final cw = size.width / art.gridWidth;
    final ch = size.height / art.gridHeight;
    final cellPaint = Paint();

    for (var r = 0; r < art.gridHeight; r++) {
      for (var c = 0; c < art.gridWidth; c++) {
        final val = art.grid[r][c];
        if (val <= 0) continue;
        var color = art.colorForNumber(val) ?? const Color(0x00000000);
        if (dimmed) color = color.withAlpha(90);
        final rect = Rect.fromLTWH(c * cw, r * ch, cw, ch);
        _drawGem(canvas, rect, color, cellPaint);
      }
    }
  }

  void _drawGem(Canvas canvas, Rect rect, Color base, Paint cellPaint) {
    final c = rect.center;
    final r = rect.shortestSide / 2;

    cellPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = base;
    canvas.drawCircle(c, r, cellPaint);

    cellPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * _gemRingWidth
      ..color = _darken(base, 0.25);
    canvas.drawCircle(c, r * _gemRingRadius, cellPaint);
    cellPaint.style = PaintingStyle.fill;

    final hl =
        Offset(c.dx - r * _gemHighlightOffset, c.dy - r * _gemHighlightOffset);
    cellPaint.color = const Color(0xFFFFFFFF).withAlpha(_gemHighlightHaloAlpha);
    canvas.drawCircle(hl, r * 0.45, cellPaint);
    cellPaint.color = const Color(0xFFFFFFFF).withAlpha(_gemHighlightCoreAlpha);
    canvas.drawCircle(hl, r * 0.28, cellPaint);
  }

  static Color _darken(Color color, double amount) {
    final f = 1.0 - amount;
    return Color.fromARGB(
      (color.a * 255).round(),
      (color.r * 255 * f).round().clamp(0, 255),
      (color.g * 255 * f).round().clamp(0, 255),
      (color.b * 255 * f).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(covariant ArtPreviewPainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.dimmed != dimmed ||
      oldDelegate.gemStyle != gemStyle;
}
