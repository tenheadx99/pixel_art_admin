import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/pixel_art.dart';
import '../core/schema/artwork_override.dart';
import '../core/schema/firestore_paths.dart';
import '../core/schema/remote_artwork.dart';
import '../services/catalog_service.dart';
import '../state/admin_state.dart';
import '../widgets/art_preview.dart';

/// Merged bundled + remote artwork list for the selected flavor. Bundled art
/// is edited via sparse overrides (hide / premium / category / order); remote
/// art is edited or deleted directly. Supports drag-reorder, per-art
/// completion stats, seasonal availability windows and raw JSON uploads
/// produced by tool/build_artworks.py.
class ArtworkListScreen extends StatefulWidget {
  const ArtworkListScreen({super.key});

  @override
  State<ArtworkListScreen> createState() => _ArtworkListScreenState();
}

class _ArtworkListScreenState extends State<ArtworkListScreen> {
  List<CatalogEntry>? _entries;
  Map<String, int> _stats = const {};
  String? _error;
  String _categoryFilter = 'All';
  bool _reorderMode = false;
  bool _orderDirty = false;

  String get _flavorId => context.read<AdminState>().flavor.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = context.read<CatalogService>();
      final entries = await catalog.loadCatalog(_flavorId);
      final stats = await catalog.loadStats(_flavorId);
      if (mounted) {
        setState(() {
          _entries = entries;
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _toggleHidden(CatalogEntry entry) {
    final catalog = context.read<CatalogService>();
    return _run(() {
      if (entry.isBundled) {
        final o = entry.override;
        return catalog.saveOverride(
          _flavorId,
          ArtworkOverride(
            artId: entry.art.id,
            hidden: entry.hidden ? null : true,
            isPremium: o?.isPremium,
            category: o?.category,
            sortOrder: o?.sortOrder,
          ),
        );
      }
      return catalog.updateRemote(
        _flavorId,
        entry.art.id,
        {'visible': entry.hidden},
      );
    });
  }

  Future<void> _togglePremium(CatalogEntry entry) {
    final catalog = context.read<CatalogService>();
    final newValue = !entry.isPremium;
    return _run(() {
      if (entry.isBundled) {
        final o = entry.override;
        return catalog.saveOverride(
          _flavorId,
          ArtworkOverride(
            artId: entry.art.id,
            hidden: o?.hidden,
            // Only keep the override when it differs from the bundled value.
            isPremium: newValue == entry.art.isPremium ? null : newValue,
            category: o?.category,
            sortOrder: o?.sortOrder,
          ),
        );
      }
      return catalog.updateRemote(
        _flavorId,
        entry.art.id,
        {'isPremium': newValue},
      );
    });
  }

  Future<void> _editCategory(CatalogEntry entry) async {
    final catalog = context.read<CatalogService>();
    final controller = TextEditingController(text: entry.category);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Category — ${entry.art.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Category',
            helperText: entry.isBundled
                ? 'Bundled value: ${entry.art.category}'
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == entry.category) return;

    await _run(() {
      if (entry.isBundled) {
        final o = entry.override;
        return catalog.saveOverride(
          _flavorId,
          ArtworkOverride(
            artId: entry.art.id,
            hidden: o?.hidden,
            isPremium: o?.isPremium,
            category: result == entry.art.category ? null : result,
            sortOrder: o?.sortOrder,
          ),
        );
      }
      return catalog.updateRemote(_flavorId, entry.art.id, {
        'category': result,
      });
    });
  }

  /// Seasonal availability window (remote artworks only).
  Future<void> _editAvailability(CatalogEntry entry) async {
    final catalog = context.read<CatalogService>();
    var from = entry.art.availableFrom;
    var until = entry.art.availableUntil;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pick(bool isFrom) async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: (isFrom ? from : until) ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 3),
            );
            if (picked != null) {
              setDialogState(() {
                if (isFrom) {
                  from = picked;
                } else {
                  // Window closes at the END of the picked day.
                  until = DateTime(
                      picked.year, picked.month, picked.day, 23, 59, 59);
                }
              });
            }
          }

          String label(DateTime? d) =>
              d == null ? 'Not set' : d.toString().split(' ').first;

          return AlertDialog(
            title: Text('Availability — ${entry.art.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Limited-time art shows a "Limited" badge in the app and '
                  'disappears when the window closes.',
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Available from'),
                  subtitle: Text(label(from)),
                  trailing: from == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => from = null),
                        ),
                  onTap: () => pick(true),
                ),
                ListTile(
                  title: const Text('Available until'),
                  subtitle: Text(label(until)),
                  trailing: until == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => until = null),
                        ),
                  onTap: () => pick(false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true) return;

    await _run(() => catalog.updateRemote(_flavorId, entry.art.id, {
          'availableFrom':
              from == null ? FieldValue.delete() : from!.toIso8601String(),
          'availableUntil':
              until == null ? FieldValue.delete() : until!.toIso8601String(),
        }));
  }

  Future<void> _deleteRemote(CatalogEntry entry) async {
    final catalog = context.read<CatalogService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete artwork?'),
        content: Text(
          '"${entry.art.name}" (${entry.art.id}) will be removed from '
          'Firestore. Players who already completed it keep their local '
          'progress records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => catalog.deleteRemote(_flavorId, entry.art.id));
  }

  /// Upload one or more artwork JSON files built with tool/build_artworks.py.
  Future<void> _uploadJson() async {
    final catalog = context.read<CatalogService>();
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null) return;

    var published = 0;
    for (final file in picked.files) {
      if (file.bytes == null) continue;
      try {
        final json =
            jsonDecode(utf8.decode(file.bytes!)) as Map<String, dynamic>;
        var art = PixelArt.fromJson(json);
        // Re-id bundled-style JSON so it can't collide with bundled ids.
        if (!RemoteArtwork.hasRemoteId(art.id)) {
          final reId = '${FirestorePaths.remoteArtIdPrefix}${art.id}';
          art = PixelArt.fromJson({...json, 'id': reId});
        }
        await catalog.publishArtwork(_flavorId, RemoteArtwork(art: art));
        published++;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name}: $e')),
          );
        }
      }
    }
    if (published > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Published $published artwork(s)')),
        );
      }
      await _load();
    }
  }

  Future<void> _saveOrder() async {
    final catalog = context.read<CatalogService>();
    await _run(() => catalog.saveOrder(_flavorId, _entries!));
    if (mounted) {
      setState(() {
        _reorderMode = false;
        _orderDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = context.watch<AdminState>().flavor;
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_error != null) {
      return Center(child: Text('Failed to load: $_error'));
    }
    final entries = _entries;
    if (entries == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = {'All', ...entries.map((e) => e.category)}.toList();
    final visible = _reorderMode || _categoryFilter == 'All'
        ? entries
        : entries.where((e) => e.category == _categoryFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${flavor.displayName} — artworks (${entries.length})',
                style: isMobile
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              if (_reorderMode) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _orderDirty ? _saveOrder : null,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save order'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _reorderMode = false;
                          _orderDirty = false;
                        });
                        _load(); // Discard unsaved moves.
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _categoryFilter,
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (c) =>
                          setState(() => _categoryFilter = c ?? 'All'),
                    ),
                    OutlinedButton.icon(
                      onPressed: entries.isEmpty
                          ? null
                          : () => setState(() => _reorderMode = true),
                      icon: const Icon(Icons.swap_vert_rounded),
                      label: Text(isMobile ? 'Reorder' : 'Reorder catalog'),
                    ),
                    FilledButton.icon(
                      onPressed: _uploadJson,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Upload JSON'),
                    ),
                    IconButton(
                      tooltip: 'Reload',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_reorderMode)
          Padding(
            padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24, 8, isMobile ? 16 : 24, 0),
            child: Text(
              'Drag rows into the order the app should show them, then Save.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (entries.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No artworks in Firestore yet.\nRun tool/seed_firestore.py '
                'to mirror the bundled catalog, or publish from the Creator tab.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (_reorderMode)
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              itemCount: entries.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final moved = entries.removeAt(oldIndex);
                  entries.insert(newIndex, moved);
                  _orderDirty = true;
                });
              },
              itemBuilder: (context, i) => Card(
                key: ValueKey(entries[i].art.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ArtPreview(
                    art: entries[i].art,
                    gemStyle: flavor.gemStyle,
                    size: 44,
                  ),
                  title: Text(entries[i].art.name),
                  subtitle: Text(entries[i].art.id),
                  trailing: const Icon(Icons.drag_handle_rounded),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              itemCount: visible.length,
              itemBuilder: (context, i) =>
                  _buildRow(context, visible[i], flavor.gemStyle, isMobile),
            ),
          ),
      ],
    );
  }

  Widget _buildRow(
      BuildContext context, CatalogEntry entry, bool gemStyle, bool isMobile) {
    final art = entry.art;
    final completions = _stats[art.id] ?? 0;
    final isDraft = !entry.isBundled && !entry.remote!.visible;

    final actionButtons = [
      IconButton(
        tooltip: entry.hidden || isDraft
            ? 'Publish / show in app'
            : 'Hide from app',
        icon: Icon(entry.hidden || isDraft
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded),
        onPressed: () => _toggleHidden(entry),
      ),
      IconButton(
        tooltip: entry.isPremium ? 'Make free' : 'Make premium',
        icon: Icon(
          Icons.workspace_premium_rounded,
          color: entry.isPremium ? Colors.amber : null,
        ),
        onPressed: () => _togglePremium(entry),
      ),
      IconButton(
        tooltip: 'Edit category',
        icon: const Icon(Icons.category_rounded),
        onPressed: () => _editCategory(entry),
      ),
      if (!entry.isBundled) ...[
        IconButton(
          tooltip: 'Availability window (seasonal / limited)',
          icon: Icon(
            Icons.event_rounded,
            color: art.availableUntil != null ? Colors.deepOrange : null,
          ),
          onPressed: () => _editAvailability(entry),
        ),
        IconButton(
          tooltip: 'Delete remote artwork',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _deleteRemote(entry),
        ),
      ],
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 4.0 : 0.0),
        child: ListTile(
          leading: ArtPreview(
              art: art, gemStyle: gemStyle, size: isMobile ? 44 : 56),
          title: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                art.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _Badge(
                label: entry.isBundled ? 'bundled' : 'remote',
                color: entry.isBundled ? Colors.blueGrey : Colors.teal,
              ),
              if (isDraft)
                const _Badge(label: 'draft', color: Colors.deepPurple)
              else if (entry.hidden)
                const _Badge(label: 'hidden', color: Colors.red),
              if (entry.isPremium)
                const _Badge(label: 'premium', color: Colors.amber),
              if (art.availableUntil != null)
                _Badge(
                  label:
                      'until ${art.availableUntil!.toString().split(' ').first}',
                  color: Colors.deepOrange,
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${art.id} • ${entry.category} • '
              '${art.gridWidth}x${art.gridHeight} • ${art.colorCount} colors • '
              'diff ${art.difficulty} • '
              '$completions completion${completions == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          trailing: isMobile
              ? PopupMenuButton<int>(
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () => _toggleHidden(entry),
                      child: Row(
                        children: [
                          Icon(entry.hidden || isDraft
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          const SizedBox(width: 8),
                          Text(entry.hidden || isDraft ? 'Publish' : 'Hide'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      onTap: () => _togglePremium(entry),
                      child: Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: entry.isPremium ? Colors.amber : null,
                          ),
                          const SizedBox(width: 8),
                          Text(entry.isPremium ? 'Make Free' : 'Make Premium'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      onTap: () => _editCategory(entry),
                      child: const Row(
                        children: [
                          Icon(Icons.category_rounded),
                          SizedBox(width: 8),
                          Text('Edit Category'),
                        ],
                      ),
                    ),
                    if (!entry.isBundled) ...[
                      PopupMenuItem(
                        onTap: () => _editAvailability(entry),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              color: art.availableUntil != null
                                  ? Colors.deepOrange
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text('Availability'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => _deleteRemote(entry),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actionButtons,
                ),
        ),
      ),
    );
  }

}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
