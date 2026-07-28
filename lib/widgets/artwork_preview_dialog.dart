import 'package:flutter/material.dart';

import '../core/models/pixel_art.dart';
import '../core/rendering/art_preview_painter.dart';

/// Modal dialog for enlarged interactive viewing of a [PixelArt].
/// Supports zoom/pan via [InteractiveViewer], rendering style toggles,
/// grid specifications (32x32, 48x48, 64x64, 96x96, etc.), and color highlighting.
class ArtworkPreviewDialog extends StatefulWidget {
  final PixelArt art;
  final bool initialGemStyle;
  final String? subtitle;

  const ArtworkPreviewDialog({
    super.key,
    required this.art,
    this.initialGemStyle = false,
    this.subtitle,
  });

  static void show(
    BuildContext context, {
    required PixelArt art,
    bool gemStyle = false,
    String? subtitle,
  }) {
    showDialog(
      context: context,
      builder: (context) => ArtworkPreviewDialog(
        art: art,
        initialGemStyle: gemStyle,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<ArtworkPreviewDialog> createState() => _ArtworkPreviewDialogState();
}

class _ArtworkPreviewDialogState extends State<ArtworkPreviewDialog> {
  late bool _gemStyle;
  int? _highlightedColor;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _gemStyle = widget.initialGemStyle;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.art;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final dialogWidth = isMobile ? MediaQuery.of(context).size.width * 0.95 : 720.0;
    final canvasSize = isMobile ? 300.0 : 420.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title + action buttons
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          art.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Specification Pills (Grid Size, Colors, Difficulty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.grid_on_rounded, size: 18),
                    label: Text('Grid: ${art.gridWidth}x${art.gridHeight}'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.palette_rounded, size: 18),
                    label: Text('${art.colorCount} Colors'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.square_foot_rounded, size: 18),
                    label: Text('${art.fillableCells} Fillable Cells'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.star_rounded, size: 18),
                    label: Text('Difficulty ${art.difficulty}'),
                  ),
                  if (art.isPremium)
                    const Chip(
                      avatar: Icon(Icons.workspace_premium_rounded,
                          size: 18, color: Colors.amber),
                      label: Text('Premium', style: TextStyle(color: Colors.amber)),
                      backgroundColor: Color(0xFFFFF8E1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Controls bar (Gem style toggle + Reset Zoom button)
              Row(
                children: [
                  const Text('Rendering Style: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Square Pixels'),
                        icon: Icon(Icons.square_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Gem Art'),
                        icon: Icon(Icons.auto_awesome_rounded, size: 16),
                      ),
                    ],
                    selected: {_gemStyle},
                    onSelectionChanged: (set) =>
                        setState(() => _gemStyle = set.first),
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: 'Reset Zoom & Pan',
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    onPressed: _resetZoom,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Enlarged Canvas with Interactive Zoom & Pan
              Center(
                child: Container(
                  width: canvasSize,
                  height: canvasSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.8,
                      maxScale: 6.0,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: art.gridWidth / art.gridHeight,
                          child: CustomPaint(
                            painter: _HighlightedArtPreviewPainter(
                              art: art,
                              gemStyle: _gemStyle,
                              highlightedColor: _highlightedColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Color Palette Inspector
              Text(
                _highlightedColor == null
                    ? 'Palette (${art.colorMap.length} colors) — tap a color to highlight grid cells:'
                    : 'Highlighting Color #$_highlightedColor — tap again to clear highlight:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final number in art.colorMap.keys.toList()..sort())
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _highlightedColor =
                              _highlightedColor == number ? null : number;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: art.colorMap[number],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            width: _highlightedColor == number ? 3 : 1,
                            color: _highlightedColor == number
                                ? Colors.black
                                : Colors.black26,
                          ),
                          boxShadow: _highlightedColor == number
                              ? [
                                  const BoxShadow(
                                      color: Colors.black26, blurRadius: 4)
                                ]
                              : null,
                        ),
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: (art.colorMap[number]!.computeLuminance() > 0.5)
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Preview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter extending default painter to dim un-highlighted colors when selected.
class _HighlightedArtPreviewPainter extends ArtPreviewPainter {
  final int? highlightedColor;

  _HighlightedArtPreviewPainter({
    required super.art,
    super.gemStyle = false,
    this.highlightedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightedColor == null) {
      super.paint(canvas, size);
      return;
    }

    final cellWidth = size.width / art.gridWidth;
    final cellHeight = size.height / art.gridHeight;

    for (var y = 0; y < art.gridHeight; y++) {
      for (var x = 0; x < art.gridWidth; x++) {
        final colorIndex = art.grid[y][x];
        if (colorIndex == 0) continue;

        final color = art.colorMap[colorIndex];
        if (color == null) continue;

        final isMatch = colorIndex == highlightedColor;
        final rect = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth,
          cellHeight,
        );

        final displayColor =
            isMatch ? color : color.withAlpha(40); // dim non-matching

        if (gemStyle) {
          final paint = Paint()..color = displayColor;
          final center = rect.center;
          final radius = (cellWidth < cellHeight ? cellWidth : cellHeight) * 0.45;
          canvas.drawCircle(center, radius, paint);
        } else {
          final paint = Paint()..color = displayColor;
          canvas.drawRect(rect, paint);
        }
      }
    }
  }
}
