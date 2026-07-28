import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/pixel_art.dart';
import '../core/schema/firestore_paths.dart';
import '../core/schema/remote_artwork.dart';
import '../services/catalog_service.dart';
import '../services/converter_service.dart';
import '../state/admin_state.dart';
import '../widgets/art_preview.dart';
import '../widgets/artwork_preview_dialog.dart';
import '../widgets/image_crop_dialog.dart';

/// Upload one or many PNGs/JPGs, tune grid size and color count with a live
/// preview (same quantization as the app's photo importer), optionally merge
/// similar palette colors, and publish — live or as a draft — to the
/// selected flavor's remote catalog. Settings apply to the whole batch.
class ArtworkCreatorScreen extends StatefulWidget {
  const ArtworkCreatorScreen({super.key});

  @override
  State<ArtworkCreatorScreen> createState() => _ArtworkCreatorScreenState();
}

class _QueuedImage {
  final String fileName;
  final Uint8List bytes;
  String name;
  Rect? cropRect;

  _QueuedImage({required this.fileName, required this.bytes, this.cropRect})
      : name = fileName
            .replaceAll(RegExp(r'\.[^.]+$'), '')
            .replaceAll(RegExp(r'[_-]+'), ' ');
}

class _ArtworkCreatorScreenState extends State<ArtworkCreatorScreen> {
  final _converter = ConverterService();
  final _category = TextEditingController(text: 'General');
  final _nameEditor = TextEditingController();

  final List<_QueuedImage> _queue = [];
  int _selected = 0;
  PixelArt? _preview;
  bool _converting = false;
  bool _publishing = false;
  Timer? _debounce;

  /// Palette number picked as the merge source (tap another color to merge).
  int? _mergeFrom;

  // Grid sizes the app supports plus larger showcase sizes; 128 caps the
  // Firestore doc at ~48 KB and the main-thread conversion stall.
  static const _gridSizes = [16, 24, 32, 48, 64, 96, 128];
  int _gridSize = 32;
  double _maxColors = 16;
  double _brightness = 0.0;
  double _contrast = 0.0;
  int _difficulty = 1;
  bool _isPremium = false;
  bool _publishAsDraft = false;
  bool _removeWhiteBg = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _category.dispose();
    _nameEditor.dispose();
    super.dispose();
  }

  _QueuedImage? get _current =>
      _queue.isEmpty ? null : _queue[_selected.clamp(0, _queue.length - 1)];

  Future<void> _pickImages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null) return;
    setState(() {
      for (final file in picked.files) {
        if (file.bytes != null) {
          _queue.add(_QueuedImage(
            fileName: file.name,
            bytes: file.bytes!,
            cropRect: null,
          ));
        }
      }
      if (_queue.isNotEmpty) _select(_queue.length - 1);
    });
    _scheduleConvert(immediate: true);
  }

  Future<void> _cropSelectedImage() async {
    final item = _current;
    if (item == null) return;
    final cropResult = await ImageCropDialog.show(
      context,
      bytes: item.bytes,
      initialCrop: item.cropRect,
    );
    setState(() {
      item.cropRect = cropResult;
    });
    _scheduleConvert(immediate: true);
  }

  void _select(int index) {
    _selected = index;
    _nameEditor.text = _queue[index].name;
    _mergeFrom = null;
  }

  /// Debounced so slider drags don't re-run main-thread quantization per tick.
  void _scheduleConvert({bool immediate = false}) {
    _debounce?.cancel();
    if (_current == null) return;
    setState(() {
      _converting = true;
      _mergeFrom = null;
    });
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 350),
      _convert,
    );
  }

  Future<void> _convert() async {
    final item = _current;
    if (item == null) return;
    // Let the busy indicator paint before the synchronous conversion stall.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    try {
      final art = _convertOne(item, id: 'preview');
      if (mounted) setState(() => _preview = art);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  PixelArt _convertOne(_QueuedImage item, {required String id}) {
    return _converter.convert(
      bytes: item.bytes,
      id: id,
      name: item.name.isEmpty ? 'Untitled' : item.name,
      gridSize: _gridSize,
      maxColors: _maxColors.round(),
      cropRect: item.cropRect,
      brightness: _brightness,
      contrast: _contrast,
      category: _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
      difficulty: _difficulty,
      isPremium: _isPremium,
      removeWhiteBackground: _removeWhiteBg,
    );
  }

  void _exportJsonDialog() {
    final preview = _preview;
    if (preview == null) return;
    final jsonString = const JsonEncoder.withIndent('  ').convert(preview.toJson());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('JSON Artwork Spec — ${preview.name}'),
        content: SizedBox(
          width: 540,
          height: 360,
          child: SelectableText(
            jsonString,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy JSON'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _mergeColor(int number) {
    final preview = _preview;
    if (preview == null) return;
    if (_mergeFrom == null) {
      setState(() => _mergeFrom = number);
      return;
    }
    if (_mergeFrom == number) {
      setState(() => _mergeFrom = null);
      return;
    }
    setState(() {
      _preview = ConverterService.mergeColors(preview, _mergeFrom!, number);
      _mergeFrom = null;
    });
  }

  String _slug(String name) => name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// Publishes the whole queue. The currently selected image keeps its
  /// (possibly color-merged) preview; the rest are converted fresh with the
  /// shared settings.
  Future<void> _publishAll() async {
    if (_queue.isEmpty) return;
    setState(() => _publishing = true);
    final catalog = context.read<CatalogService>();
    final flavorId = context.read<AdminState>().flavor.id;

    var published = 0;
    try {
      for (var i = 0; i < _queue.length; i++) {
        final item = _queue[i];
        final id = '${FirestorePaths.remoteArtIdPrefix}${_slug(item.name)}_'
            '${DateTime.now().millisecondsSinceEpoch}';
        PixelArt art;
        if (i == _selected && _preview != null) {
          final p = _preview!;
          art = PixelArt(
            id: id,
            name: item.name,
            gridWidth: p.gridWidth,
            gridHeight: p.gridHeight,
            grid: p.grid,
            colorMap: p.colorMap,
            category: _category.text.trim().isEmpty
                ? 'General'
                : _category.text.trim(),
            difficulty: _difficulty,
            isPremium: _isPremium,
          );
        } else {
          art = _convertOne(item, id: id);
        }
        await catalog.publishArtwork(
          flavorId,
          RemoteArtwork(art: art, visible: !_publishAsDraft),
        );
        published++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_publishAsDraft
                ? 'Saved $published draft(s) — publish from the Artworks tab'
                : 'Published $published artwork(s)'),
          ),
        );
        setState(() {
          _queue.clear();
          _preview = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Publish failed after $published item(s): $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = context.watch<AdminState>().flavor;
    final preview = _preview;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final controlsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_queue.isEmpty
                  ? 'Choose images (PNG/JPG)'
                  : 'Add more images'),
            ),
            if (_current != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _cropSelectedImage,
                icon: Icon(
                  Icons.crop_rounded,
                  color: _current?.cropRect != null ? Colors.amber : null,
                ),
                label: Text(
                  _current?.cropRect != null ? 'Cropped' : 'Crop Image',
                ),
              ),
            ],
          ],
        ),
        if (_queue.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _queue.length; i++)
                InputChip(
                  avatar: _queue[i].cropRect != null
                      ? const Icon(Icons.crop_rounded, size: 16, color: Colors.amber)
                      : null,
                  label: Text(
                    _queue[i].name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: i == _selected,
                  onSelected: (_) {
                    setState(() => _select(i));
                    _scheduleConvert(immediate: true);
                  },
                  onDeleted: () {
                    setState(() {
                      _queue.removeAt(i);
                      if (_queue.isEmpty) {
                        _preview = null;
                      } else {
                        _select(_selected.clamp(0, _queue.length - 1));
                      }
                    });
                    if (_queue.isNotEmpty) {
                      _scheduleConvert(immediate: true);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameEditor,
            decoration: const InputDecoration(
              labelText: 'Name (selected image)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _current?.name = v,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _category,
          decoration: const InputDecoration(
            labelText: 'Category (whole batch)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Grid size (long edge): $_gridSize'),
        Slider(
          value: _gridSizes.indexOf(_gridSize).toDouble(),
          min: 0,
          max: (_gridSizes.length - 1).toDouble(),
          divisions: _gridSizes.length - 1,
          label: '$_gridSize',
          onChanged: (v) {
            setState(() => _gridSize = _gridSizes[v.round()]);
            _scheduleConvert();
          },
        ),
        Text('Max colors: ${_maxColors.round()}'),
        Slider(
          value: _maxColors,
          min: 4,
          max: 32,
          divisions: 28,
          label: '${_maxColors.round()}',
          onChanged: (v) {
            setState(() => _maxColors = v);
            _scheduleConvert();
          },
        ),
        Text('Brightness adjustment: ${(_brightness * 100).round()}%'),
        Slider(
          value: _brightness,
          min: -0.5,
          max: 0.5,
          divisions: 20,
          label: '${(_brightness * 100).round()}%',
          onChanged: (v) {
            setState(() => _brightness = v);
            _scheduleConvert();
          },
        ),
        Text('Contrast adjustment: ${(_contrast * 100).round()}%'),
        Slider(
          value: _contrast,
          min: -0.5,
          max: 0.5,
          divisions: 20,
          label: '${(_contrast * 100).round()}%',
          onChanged: (v) {
            setState(() => _contrast = v);
            _scheduleConvert();
          },
        ),
        Row(
          children: [
            const Text('Difficulty:'),
            const SizedBox(width: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (s) =>
                  setState(() => _difficulty = s.first),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remove white background'),
          subtitle: const Text(
              'Near-white pixels become empty cells (for JPGs)'),
          value: _removeWhiteBg,
          onChanged: (v) {
            setState(() => _removeWhiteBg = v);
            _scheduleConvert();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Premium artwork'),
          value: _isPremium,
          onChanged: (v) => setState(() => _isPremium = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Publish as draft'),
          subtitle: const Text(
              'Hidden from users until made visible in Artworks'),
          value: _publishAsDraft,
          onChanged: (v) => setState(() => _publishAsDraft = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed:
                  (_queue.isEmpty || _converting || _publishing)
                      ? null
                      : _publishAll,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: Text(_publishing
                  ? 'Publishing…'
                  : _queue.length > 1
                      ? 'Publish ${_queue.length} to ${flavor.displayName}'
                      : 'Publish to ${flavor.displayName}'),
            ),
            OutlinedButton.icon(
              onPressed: _preview == null ? null : _exportJsonDialog,
              icon: const Icon(Icons.code_rounded),
              label: const Text('Export JSON'),
            ),
          ],
        ),
      ],
    );

    final previewColumn = Column(
      children: [
        if (_converting) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        if (preview == null)
          Container(
            height: isMobile ? 240 : 360,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Preview appears here'),
          )
        else ...[
          Tooltip(
            message: 'Tap to view enlarged preview',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ArtworkPreviewDialog.show(
                context,
                art: preview,
                gemStyle: flavor.gemStyle,
                subtitle: 'Live Conversion Preview',
              ),
              child: Stack(
                children: [
                  ArtPreview(
                    art: preview,
                    gemStyle: flavor.gemStyle,
                    size: isMobile ? 260 : 360,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${preview.gridWidth}x${preview.gridHeight} • '
            '${preview.colorCount} colors • '
            '${preview.fillableCells} fillable cells',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 12),
          Text(
            _mergeFrom == null
                ? 'Palette — tap a color, then another, to merge them'
                : 'Merging color $_mergeFrom — tap the target color '
                  '(or tap it again to cancel)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final number
                  in preview.colorMap.keys.toList()..sort())
                GestureDetector(
                  onTap: () => _mergeColor(number),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: preview.colorMap[number],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        width: _mergeFrom == number ? 3 : 1,
                        color: _mergeFrom == number
                            ? Colors.black
                            : Colors.black26,
                      ),
                    ),
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (preview.colorMap[number]!
                                    .computeLuminance() >
                                0.5)
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      children: [
        Text(
          '${flavor.displayName} — artwork creator',
          style: isMobile
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (isMobile) ...[
          previewColumn,
          const SizedBox(height: 24),
          controlsColumn,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: controlsColumn),
              const SizedBox(width: 32),
              Expanded(child: previewColumn),
            ],
          ),
        ],
      ],
    );
  }

}
