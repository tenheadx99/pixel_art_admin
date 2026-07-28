import 'dart:ui' show Rect;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/models/pixel_art.dart';
import '../core/services/image_processing_service.dart';

/// Converts an uploaded image into a [PixelArt] with the exact same pipeline
/// as the app's photo importer and tool/build_artworks.py.
///
/// Runs on the main thread — `compute` is a no-op on Flutter web. A 128-cap
/// on grid size plus a pre-shrink of huge sources keeps the stall short; the
/// UI debounces slider changes and shows a busy indicator.
class ConverterService {
  final ImageProcessingService _processor = ImageProcessingService();

  /// Sources above this edge length are pre-shrunk before quantization; the
  /// grid downscale below makes finer detail unobservable anyway.
  static const int _maxSourceEdge = 1024;

  PixelArt convert({
    required Uint8List bytes,
    required String id,
    required String name,
    required int gridSize,
    required int maxColors,
    Rect? cropRect,
    String category = 'General',
    int difficulty = 1,
    bool isPremium = false,
    bool removeWhiteBackground = false,
  }) {
    var source = _processor.loadImageFromBytes(bytes);
    if (cropRect != null) {
      final cropX = (cropRect.left * source.width).round().clamp(0, source.width - 1);
      final cropY = (cropRect.top * source.height).round().clamp(0, source.height - 1);
      final cropW = (cropRect.width * source.width).round().clamp(1, source.width - cropX);
      final cropH = (cropRect.height * source.height).round().clamp(1, source.height - cropY);
      source = img.copyCrop(source, x: cropX, y: cropY, width: cropW, height: cropH);
    }
    if (removeWhiteBackground) {
      source = _stripWhiteBackground(source);
    }

    if (source.width > _maxSourceEdge || source.height > _maxSourceEdge) {
      final landscape = source.width >= source.height;
      source = img.copyResize(
        source,
        width: landscape ? _maxSourceEdge : null,
        height: landscape ? null : _maxSourceEdge,
        interpolation: img.Interpolation.average,
      );
    }

    // Preserve aspect ratio: the long edge gets gridSize cells.
    final landscape = source.width >= source.height;
    final gridWidth = landscape
        ? gridSize
        : (gridSize * source.width / source.height).round().clamp(1, gridSize);
    final gridHeight = landscape
        ? (gridSize * source.height / source.width).round().clamp(1, gridSize)
        : gridSize;

    final scaled = _processor.downscaleToGrid(source, gridWidth, gridHeight);
    final quantized = _processor.quantizeColors(scaled, maxColors);
    final grid = _processor.buildGridFromImage(scaled, quantized);
    final colorMap = _processor.buildColorMap(quantized);

    return PixelArt(
      id: id,
      name: name,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      grid: grid,
      colorMap: colorMap,
      category: category,
      difficulty: difficulty,
      isPremium: isPremium,
    );
  }

  /// Makes near-white pixels transparent — for JPGs and PNGs exported on a
  /// solid white canvas, so the background becomes empty cells instead of a
  /// giant white color region.
  img.Image _stripWhiteBackground(img.Image source) {
    final out = img.Image.from(source);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        if (p.r >= 245 && p.g >= 245 && p.b >= 245) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return out;
  }

  /// Repaints every [from] cell as [to] and drops [from] from the palette —
  /// the "merge similar colors" cleanup tool. Numbers may become sparse,
  /// which the app handles (it derives the palette from the grid).
  static PixelArt mergeColors(PixelArt art, int from, int to) {
    if (from == to || !art.colorMap.containsKey(to)) return art;
    final grid = [
      for (final row in art.grid)
        [for (final cell in row) cell == from ? to : cell],
    ];
    final colorMap = Map.of(art.colorMap)..remove(from);
    return PixelArt(
      id: art.id,
      name: art.name,
      gridWidth: art.gridWidth,
      gridHeight: art.gridHeight,
      grid: grid,
      colorMap: colorMap,
      category: art.category,
      difficulty: art.difficulty,
      isPremium: art.isPremium,
    );
  }
}
