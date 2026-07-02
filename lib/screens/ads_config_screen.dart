import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/schema/ads_config.dart';
import '../services/config_service.dart';
import '../state/admin_state.dart';

/// Per-flavor ads control: master on/off switch, the four AdMob unit ids and
/// the pacing knobs. Empty fields mean "no override" — the app then falls
/// back to Remote Config, then to its built-in defaults.
class AdsConfigScreen extends StatefulWidget {
  const AdsConfigScreen({super.key});

  @override
  State<AdsConfigScreen> createState() => _AdsConfigScreenState();
}

class _AdsConfigScreenState extends State<AdsConfigScreen> {
  bool _loading = true;
  bool _saving = false;

  bool? _showAds;
  final _banner = TextEditingController();
  final _interstitial = TextEditingController();
  final _rewarded = TextEditingController();
  final _appOpen = TextEditingController();
  final _interstitialCooldown = TextEditingController();
  final _interstitialMinSession = TextEditingController();
  final _appOpenCooldown = TextEditingController();

  String get _flavorId => context.read<AdminState>().flavor.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _controllers => [
        _banner,
        _interstitial,
        _rewarded,
        _appOpen,
        _interstitialCooldown,
        _interstitialMinSession,
        _appOpenCooldown,
      ];

  Future<void> _load() async {
    final config = await context.read<ConfigService>().loadAds(_flavorId);
    if (!mounted) return;
    setState(() {
      _showAds = config.showAds;
      _banner.text = config.bannerAdUnitId ?? '';
      _interstitial.text = config.interstitialAdUnitId ?? '';
      _rewarded.text = config.rewardedAdUnitId ?? '';
      _appOpen.text = config.appOpenAdUnitId ?? '';
      _interstitialCooldown.text =
          config.interstitialCooldownS?.toString() ?? '';
      _interstitialMinSession.text =
          config.interstitialMinSessionS?.toString() ?? '';
      _appOpenCooldown.text = config.appOpenCooldownS?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = AdsConfig(
      showAds: _showAds,
      bannerAdUnitId: _banner.text.trim().isEmpty ? null : _banner.text.trim(),
      interstitialAdUnitId:
          _interstitial.text.trim().isEmpty ? null : _interstitial.text.trim(),
      rewardedAdUnitId:
          _rewarded.text.trim().isEmpty ? null : _rewarded.text.trim(),
      appOpenAdUnitId:
          _appOpen.text.trim().isEmpty ? null : _appOpen.text.trim(),
      interstitialCooldownS: int.tryParse(_interstitialCooldown.text),
      interstitialMinSessionS: int.tryParse(_interstitialMinSession.text),
      appOpenCooldownS: int.tryParse(_appOpenCooldown.text),
    );
    try {
      await context.read<ConfigService>().saveAds(_flavorId, config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ads config saved')),
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
    const d = AdsConfig.defaults;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${flavor.displayName} — ads',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Show ads'),
                subtitle: Text(_showAds == null
                    ? 'No override — app follows Remote Config '
                      '(${flavor.id == 'original' ? 'pixelyart' : flavor.id}_show_ads)'
                    : (_showAds!
                        ? 'Override: ads ENABLED for this flavor'
                        : 'Override: ads DISABLED for this flavor')),
                value: _showAds ?? false,
                onChanged: (v) => setState(() => _showAds = v),
              ),
              if (_showAds != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: TextButton(
                      onPressed: () => setState(() => _showAds = null),
                      child: const Text('Clear override'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Ad unit IDs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Leave a field empty to keep the current Remote Config / built-in value.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _field(_banner, 'Banner ad unit ID', hint: d.bannerAdUnitId!),
        _field(_interstitial, 'Interstitial ad unit ID',
            hint: d.interstitialAdUnitId!),
        _field(_rewarded, 'Rewarded ad unit ID', hint: d.rewardedAdUnitId!),
        _field(_appOpen, 'App-open ad unit ID', hint: d.appOpenAdUnitId!),
        const SizedBox(height: 16),
        Text('Pacing', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _field(_interstitialCooldown,
            'Interstitial cooldown (seconds)',
            hint: '${d.interstitialCooldownS}', number: true),
        _field(_interstitialMinSession,
            'Interstitial minimum session (seconds)',
            hint: '${d.interstitialMinSessionS}', number: true),
        _field(_appOpenCooldown, 'App-open cooldown (seconds)',
            hint: '${d.appOpenCooldownS}', number: true),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save ads config'),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required String hint,
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: 'Clear (use default)',
            icon: const Icon(Icons.backspace_outlined, size: 18),
            onPressed: () => controller.clear(),
          ),
        ),
      ),
    );
  }
}
