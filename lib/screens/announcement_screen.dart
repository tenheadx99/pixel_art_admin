import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/schema/announcement_config.dart';
import '../services/config_service.dart';
import '../state/admin_state.dart';

/// Dismissible in-app banner (cross-promo, news). Saving re-stamps the
/// announcement, so users who dismissed an older one see the new version.
class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _linkUrl = TextEditingController();

  String get _flavorId => context.read<AdminState>().flavor.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config =
        await context.read<ConfigService>().loadAnnouncement(_flavorId);
    if (!mounted) return;
    setState(() {
      _enabled = config.enabled;
      _title.text = config.title;
      _message.text = config.message;
      _linkUrl.text = config.linkUrl ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ConfigService>().saveAnnouncement(
            _flavorId,
            AnnouncementConfig(
              enabled: _enabled,
              title: _title.text.trim(),
              message: _message.text.trim(),
              linkUrl:
                  _linkUrl.text.trim().isEmpty ? null : _linkUrl.text.trim(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Announcement saved — it will re-appear even for '
                  'users who dismissed a previous one')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final flavor = context.watch<AdminState>().flavor;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${flavor.displayName} — announcement',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Shown as a dismissible banner at the top of the home screen. '
          'Use it for news or to cross-promote your other apps.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Show announcement'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Title (optional)',
            hintText: 'New artwork pack!',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: '20 new anime pixels just landed — check the gallery!',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _linkUrl,
          decoration: const InputDecoration(
            labelText: 'Link URL (optional — adds a "Check it out" button)',
            hintText: 'https://play.google.com/store/apps/details?id=…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.campaign_rounded),
            label: Text(_saving ? 'Saving…' : 'Save announcement'),
          ),
        ),
      ],
    );
  }
}
