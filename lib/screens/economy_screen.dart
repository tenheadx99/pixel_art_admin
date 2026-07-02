import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/schema/economy_config.dart';
import '../services/config_service.dart';
import '../state/admin_state.dart';

/// Grouped numeric form over every tunable economy value. The app's built-in
/// default is shown next to each field; a single Save writes the whole doc.
///
/// Note: values only affect app versions that read Firestore config, and
/// startingDiamonds only affects fresh installs — balances live on-device.
class EconomyScreen extends StatefulWidget {
  const EconomyScreen({super.key});

  @override
  State<EconomyScreen> createState() => _EconomyScreenState();
}

class _EconomyScreenState extends State<EconomyScreen> {
  bool _loading = true;
  bool _saving = false;
  final Map<String, TextEditingController> _fields = {};

  String get _flavorId => context.read<AdminState>().flavor.id;

  // (key, label, default) grouped by section — keys match EconomyConfig maps.
  static const _groups = <String, List<(String, String, int)>>{
    'Earning diamonds': [
      ('startingDiamonds', 'Starting balance (fresh installs)', 320),
      ('diamondsPerCompletion', 'Per artwork completion', 50),
      ('diamondsDailyBonus', 'Daily art bonus', 25),
      ('diamondsPerLevelUp', 'Per level-up', 50),
      ('diamondsPerAchievement', 'Per achievement', 15),
      ('doubleRewardMultiplier', '"Watch ad to double" multiplier', 2),
    ],
    'Shop prices (diamonds)': [
      ('diamondCostUnlockArt', 'Unlock a premium artwork', 200),
      ('diamondCostHint', 'Hint', 30),
      ('diamondCostWand', 'Magic wand', 40),
      ('diamondCostBomb', 'Bomb', 40),
      ('diamondCostBrush', 'Brush', 40),
    ],
    'Rewarded ads & purchases': [
      ('hintsPerRewardedAd', 'Hints per rewarded ad', 3),
      ('wandsPerRewardedAd', 'Wands per rewarded ad', 2),
      ('hintsPerPurchase', 'Hints per IAP pack', 5),
      ('wandsPerPurchase', 'Wands per IAP pack', 10),
    ],
    'XP & levels': [
      ('xpPerCell', 'XP per cell', 1),
      ('xpPerCompletion', 'XP per completion', 100),
      ('xpLevelDivisor', 'Level curve divisor', 100),
    ],
    'Milestone gifts (30% / 65% / 100%)': [
      ('milestone30Bomb', 'Bombs at 30%', 1),
      ('milestone65Diamonds', 'Diamonds at 65%', 20),
      ('milestone100Diamonds', 'Diamonds at 100%', 30),
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final config =
        await context.read<ConfigService>().loadEconomy(_flavorId);
    if (!mounted) return;
    final map = config.toMap();
    setState(() {
      for (final group in _groups.values) {
        for (final (key, _, _) in group) {
          _fields[key] = TextEditingController(text: '${map[key]}');
        }
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Blank/invalid fields fall back to the built-in default via fromMap.
    final map = <String, dynamic>{
      for (final e in _fields.entries)
        if (int.tryParse(e.value.text.trim()) != null)
          e.key: int.parse(e.value.text.trim()),
    };
    try {
      await context
          .read<ConfigService>()
          .saveEconomy(_flavorId, EconomyConfig.fromMap(map));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Economy config saved')),
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

  void _resetDefaults() {
    final map = EconomyConfig.defaults.toMap();
    for (final e in _fields.entries) {
      e.value.text = '${map[e.key]}';
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
          '${flavor.displayName} — economy',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Changes apply to app versions that read remote config. Player '
          'balances are stored on-device and are not affected; the starting '
          'balance only applies to fresh installs.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        for (final group in _groups.entries) ...[
          Text(group.key, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (key, label, def) in group.value)
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _fields[key],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: label,
                      helperText: 'default: $def',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save economy config'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _resetDefaults,
              child: const Text('Reset all to defaults'),
            ),
          ],
        ),
      ],
    );
  }
}
