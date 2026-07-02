import 'package:flutter/material.dart';

import '../core/models/pixel_art.dart';
import '../core/rendering/art_preview_painter.dart';

/// Renders a [PixelArt] preview at its own aspect ratio on a light backdrop,
/// gem-styled for the Gem Art flavor.
class ArtPreview extends StatelessWidget {
  final PixelArt art;
  final bool gemStyle;
  final double size;

  const ArtPreview({
    super.key,
    required this.art,
    this.gemStyle = false,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: AspectRatio(
          aspectRatio: art.gridWidth / art.gridHeight,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: ArtPreviewPainter(art: art, gemStyle: gemStyle),
            ),
          ),
        ),
      ),
    );
  }
}
