import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/catalog_service.dart';
import '../state/admin_state.dart';
import '../widgets/art_preview.dart';

/// Schedule a specific artwork as the Daily Pixel for chosen dates
/// (`daily_schedule/{yyyy-MM-dd}` → artId). Unscheduled days fall back to
/// the app's built-in rotation.
class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  Map<String, String>? _schedule; // date -> artId
  List<CatalogEntry>? _catalog;
  String? _error;

  String get _flavorId => context.read<AdminState>().flavor.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = context.read<CatalogService>();
      final catalog = await service.loadCatalog(_flavorId);
      final schedule = await service.loadSchedule(_flavorId);
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _schedule = schedule;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  CatalogEntry? _entryFor(String artId) {
    for (final e in _catalog ?? const <CatalogEntry>[]) {
      if (e.art.id == artId) return e;
    }
    return null;
  }

  Future<void> _addEntry() async {
    final catalog = _catalog;
    if (catalog == null || catalog.isEmpty) return;
    final service = context.read<CatalogService>();

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final selectable =
        catalog.where((e) => !e.hidden).toList();
    final artId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Daily Pixel for ${CatalogService.dateKey(date)}'),
        children: [
          SizedBox(
            width: 420,
            height: 420,
            child: ListView.builder(
              itemCount: selectable.length,
              itemBuilder: (context, i) {
                final entry = selectable[i];
                return ListTile(
                  leading: ArtPreview(art: entry.art, size: 40),
                  title: Text(entry.art.name),
                  subtitle: Text(entry.art.id),
                  onTap: () => Navigator.pop(context, entry.art.id),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (artId == null) return;

    try {
      await service.saveScheduleEntry(
          _flavorId, CatalogService.dateKey(date), artId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _delete(String date) async {
    try {
      await context.read<CatalogService>().deleteScheduleEntry(_flavorId, date);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = context.watch<AdminState>().flavor;
    if (_error != null) return Center(child: Text('Failed to load: $_error'));
    final schedule = _schedule;
    if (schedule == null || _catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Text(
                '${flavor.displayName} — Daily Pixel schedule',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Schedule a day'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            'Unscheduled days use the app\'s automatic rotation. Great for '
            'holidays and themed days.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (schedule.isEmpty)
          const Expanded(
            child: Center(child: Text('Nothing scheduled — rotation applies.')),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                for (final entry in schedule.entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _entryFor(entry.value) == null
                          ? const Icon(Icons.broken_image_rounded)
                          : ArtPreview(
                              art: _entryFor(entry.value)!.art,
                              gemStyle: flavor.gemStyle,
                              size: 48,
                            ),
                      title: Text(entry.key),
                      subtitle: Text(
                        _entryFor(entry.value)?.art.name ??
                            '${entry.value} (not in catalog!)',
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove (rotation applies again)',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(entry.key),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
