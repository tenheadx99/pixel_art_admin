import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/schema/app_version_config.dart';
import '../services/config_service.dart';
import '../state/admin_state.dart';

/// Force-update controls: minimum required version and the store URL shown
/// on the blocking update screen.
class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _maintenance = false;
  final _minVersion = TextEditingController();
  final _updateUrl = TextEditingController();
  final _maintenanceMessage = TextEditingController();

  String get _flavorId => context.read<AdminState>().flavor.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minVersion.dispose();
    _updateUrl.dispose();
    _maintenanceMessage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await context.read<ConfigService>().loadApp(_flavorId);
    if (!mounted) return;
    setState(() {
      _minVersion.text = config.minVersion ?? '';
      _updateUrl.text = config.forceUpdateUrl ?? '';
      _maintenance = config.maintenance;
      _maintenanceMessage.text = config.maintenanceMessage ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = AppVersionConfig(
      minVersion:
          _minVersion.text.trim().isEmpty ? null : _minVersion.text.trim(),
      forceUpdateUrl:
          _updateUrl.text.trim().isEmpty ? null : _updateUrl.text.trim(),
      maintenance: _maintenance,
      maintenanceMessage: _maintenanceMessage.text.trim().isEmpty
          ? null
          : _maintenanceMessage.text.trim(),
    );
    try {
      await context.read<ConfigService>().saveApp(_flavorId, config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App config saved')),
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
          '${flavor.displayName} — app',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Installs older than the minimum version see a blocking update '
          'screen pointing at the URL below. Leave empty for no forced update.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _minVersion,
          decoration: const InputDecoration(
            labelText: 'Minimum required version',
            hintText: '1.0.0',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _updateUrl,
          decoration: InputDecoration(
            labelText: 'Force-update URL',
            hintText:
                'https://play.google.com/store/apps/details?id=${flavor.androidAppId}',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Text('Maintenance mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Kill-switch: while enabled, the app shows a blocking "be right '
          'back" screen on launch. Use sparingly.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(_maintenance
              ? 'MAINTENANCE MODE IS ON — users are blocked'
              : 'Maintenance mode off'),
          value: _maintenance,
          activeTrackColor: Theme.of(context).colorScheme.error,
          onChanged: (v) => setState(() => _maintenance = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _maintenanceMessage,
          decoration: const InputDecoration(
            labelText: 'Maintenance message (optional)',
            hintText: 'We are doing some quick maintenance…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save app config'),
          ),
        ),
      ],
    );
  }
}
