import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Interactive modal dialog for selecting a crop box on an image byte array.
/// Returns normalized [Rect] with values from 0.0 to 1.0.
class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final Rect? initialCrop;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    this.initialCrop,
  });

  static Future<Rect?> show(
    BuildContext context, {
    required Uint8List bytes,
    Rect? initialCrop,
  }) {
    return showDialog<Rect?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageCropDialog(
        imageBytes: bytes,
        initialCrop: initialCrop,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  // Normalized 0..1 bounding box
  double _left = 0.0;
  double _top = 0.0;
  double _width = 1.0;
  double _height = 1.0;

  String _selectedAspect = '1:1'; // Default to 1:1 Square

  @override
  void initState() {
    super.initState();
    if (widget.initialCrop != null) {
      _left = widget.initialCrop!.left.clamp(0.0, 0.9);
      _top = widget.initialCrop!.top.clamp(0.0, 0.9);
      _width = widget.initialCrop!.width.clamp(0.1, 1.0 - _left);
      _height = widget.initialCrop!.height.clamp(0.1, 1.0 - _top);
    } else {
      _applyAspectRatio('1:1');
    }
  }

  void _applyAspectRatio(String aspect) {
    setState(() {
      _selectedAspect = aspect;
      switch (aspect) {
        case '1:1':
          final size = _width < _height ? _width : _height;
          _width = size;
          _height = size;
          break;
        case '4:3':
          _width = 1.0;
          _height = 0.75;
          _left = 0.0;
          _top = 0.125;
          break;
        case '16:9':
          _width = 1.0;
          _height = 0.5625;
          _left = 0.0;
          _top = 0.21875;
          break;
        case 'Free':
        default:
          break;
      }
    });
  }

  void _resetCrop() {
    setState(() {
      _left = 0.0;
      _top = 0.0;
      _width = 1.0;
      _height = 1.0;
      _selectedAspect = 'Free';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFullImage =
        _left == 0.0 && _top == 0.0 && _width == 1.0 && _height == 1.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.crop_rounded, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Crop Source Image',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, widget.initialCrop),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Aspect ratio selectors
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Aspect Ratio:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final ratio in ['Free', '1:1', '4:3', '16:9'])
                  ChoiceChip(
                    label: Text(ratio),
                    selected: _selectedAspect == ratio,
                    onSelected: (selected) {
                      if (selected) _applyAspectRatio(ratio);
                    },
                  ),
                OutlinedButton.icon(
                  onPressed: _resetCrop,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset Crop'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Interactive Crop Container
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxW = constraints.maxWidth;
                    final boxH = constraints.maxHeight;

                    return Stack(
                      children: [
                        // Background image centered
                        Center(
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                            width: boxW,
                            height: boxH,
                          ),
                        ),
                        // Semi-transparent overlay mask
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CropOverlayPainter(
                              cropRect: Rect.fromLTWH(
                                _left * boxW,
                                _top * boxH,
                                _width * boxW,
                                _height * boxH,
                              ),
                            ),
                          ),
                        ),
                        // Draggable Crop Box overlay
                        Positioned(
                          left: _left * boxW,
                          top: _top * boxH,
                          width: _width * boxW,
                          height: _height * boxH,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                final deltaX = details.delta.dx / boxW;
                                final deltaY = details.delta.dy / boxH;
                                _left = (_left + deltaX).clamp(0.0, 1.0 - _width);
                                _top = (_top + deltaY).clamp(0.0, 1.0 - _height);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.amberAccent, width: 2),
                                color: Colors.white.withAlpha(20),
                              ),
                              child: Stack(
                                children: [
                                  // Grid guide lines
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _GridGuidePainter(),
                                    ),
                                  ),
                                  // Drag indicator label
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(4)),
                                      ),
                                      child: const Text(
                                        'Drag to Move Crop Area',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Crop Region Sliders (X, Y, Width, Height controls for fine tuning)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crop Width: ${(_width * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall),
                      Slider(
                        value: _width,
                        min: 0.1,
                        max: (1.0 - _left).clamp(0.1, 1.0),
                        onChanged: (val) => setState(() => _width = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crop Height: ${(_height * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall),
                      Slider(
                        value: _height,
                        min: 0.1,
                        max: (1.0 - _top).clamp(0.1, 1.0),
                        onChanged: (val) => setState(() => _height = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, widget.initialCrop),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    final cropResult = isFullImage
                        ? null
                        : Rect.fromLTWH(_left, _top, _width, _height);
                    Navigator.pop(context, cropResult);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(isFullImage ? 'Use Full Image' : 'Apply Crop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropPath = Path()..addRect(cropRect);
    final overlayPath =
        Path.combine(PathOperation.difference, fullPath, cropPath);

    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}

class _GridGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.0;

    // Draw 3x3 grid lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(2 * size.width / 3, 0), Offset(2 * size.width / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3), Offset(size.width, 2 * size.height / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
