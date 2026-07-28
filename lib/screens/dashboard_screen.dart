import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/schema/firestore_paths.dart';
import '../services/catalog_service.dart';
import '../services/config_service.dart';
import '../state/admin_state.dart';

/// Per-flavor overview: catalog version, artwork counts and when each config
/// doc was last touched.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final flavorId = context.read<AdminState>().flavor.id;
    final catalogService = context.read<CatalogService>();
    final configService = context.read<ConfigService>();
    final db = FirebaseFirestore.instance;

    final flavorDoc = await db.doc(FirestorePaths.flavorDoc(flavorId)).get();
    final catalog = await catalogService.loadCatalog(flavorId);
    final updated = await configService.lastUpdated(flavorId);

    final categoryCounts = <String, int>{};
    for (final entry in catalog) {
      categoryCounts[entry.category] = (categoryCounts[entry.category] ?? 0) + 1;
    }

    final version =
        (flavorDoc.data()?[FlavorDocFields.catalogVersion] as num?)?.toInt();
    return _DashboardData(
      catalogVersion: version,
      totalCount: catalog.length,
      bundledCount: catalog.where((e) => e.isBundled).length,
      remoteCount: catalog.where((e) => !e.isBundled).length,
      hiddenCount: catalog.where((e) => e.hidden).length,
      premiumCount: catalog.where((e) => e.isPremium).length,
      categoryCounts: categoryCounts,
      configUpdated: updated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flavor = context.watch<AdminState>().flavor;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data!;
        return ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            Text(
              '${flavor.displayName} — overview',
              style: isMobile
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              d.catalogVersion == null
                  ? 'No flavor doc yet — run the seed scripts (see tool/README.md) '
                    'to initialize this flavor.'
                  : 'Catalog version ${d.catalogVersion} — the app refetches '
                    'artwork when this number grows.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 450
                    ? (constraints.maxWidth - 12) / 2
                    : 200.0;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Total Artworks',
                      value: '${d.totalCount}',
                      icon: Icons.photo_library_rounded,
                      width: cardWidth,
                    ),
                    _StatCard(
                      label: 'Bundled artworks',
                      value: '${d.bundledCount}',
                      icon: Icons.inventory_2_rounded,
                      width: cardWidth,
                    ),
                    _StatCard(
                      label: 'Remote artworks',
                      value: '${d.remoteCount}',
                      icon: Icons.cloud_done_rounded,
                      width: cardWidth,
                    ),
                    _StatCard(
                      label: 'Hidden',
                      value: '${d.hiddenCount}',
                      icon: Icons.visibility_off_rounded,
                      width: cardWidth,
                    ),
                    _StatCard(
                      label: 'Premium',
                      value: '${d.premiumCount}',
                      icon: Icons.workspace_premium_rounded,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text('Category Breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (d.categoryCounts.isEmpty)
              const Text('No catalog categories found.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final entry in d.categoryCounts.entries) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${entry.value} (${(d.totalCount > 0 ? (entry.value / d.totalCount * 100).round() : 0)}%)',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: d.totalCount > 0 ? entry.value / d.totalCount : 0,
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Text('Config docs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in d.configUpdated.entries)
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 0 : 16, vertical: 0),
                leading: const Icon(Icons.settings_rounded),
                title: Text('config/${entry.key}'),
                subtitle: Text(
                  entry.value == null
                      ? 'Never written — app uses Remote Config / built-in defaults'
                      : 'Last updated ${entry.value}',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardData {
  final int? catalogVersion;
  final int totalCount;
  final int bundledCount;
  final int remoteCount;
  final int hiddenCount;
  final int premiumCount;
  final Map<String, int> categoryCounts;
  final Map<String, DateTime?> configUpdated;

  const _DashboardData({
    required this.catalogVersion,
    required this.totalCount,
    required this.bundledCount,
    required this.remoteCount,
    required this.hiddenCount,
    required this.premiumCount,
    required this.categoryCounts,
    required this.configUpdated,
  });
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double width;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

