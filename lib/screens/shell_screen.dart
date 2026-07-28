import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/flavors.dart';
import '../services/admin_auth_service.dart';
import '../state/admin_state.dart';
import 'ads_config_screen.dart';
import 'announcement_screen.dart';
import 'app_config_screen.dart';
import 'artwork_creator_screen.dart';
import 'artwork_list_screen.dart';
import 'daily_schedule_screen.dart';
import 'dashboard_screen.dart';
import 'economy_screen.dart';
import 'notifications_screen.dart';

/// Side navigation + flavor selector. Every section edits the flavor picked
/// here; switching flavors rebuilds the active section with fresh data.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  static const _sections = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.image_rounded, label: 'Artworks'),
    (icon: Icons.auto_awesome_rounded, label: 'Creator'),
    (icon: Icons.today_rounded, label: 'Daily'),
    (icon: Icons.ads_click_rounded, label: 'Ads'),
    (icon: Icons.diamond_rounded, label: 'Economy'),
    (icon: Icons.campaign_rounded, label: 'Announce'),
    (icon: Icons.notifications_active_rounded, label: 'Push'),
    (icon: Icons.system_update_alt_rounded, label: 'App'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final flavor = state.flavor;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final activeChild = KeyedSubtree(
      key: ValueKey('${flavor.id}-$_index'),
      child: switch (_index) {
        0 => const DashboardScreen(),
        1 => const ArtworkListScreen(),
        2 => const ArtworkCreatorScreen(),
        3 => const DailyScheduleScreen(),
        4 => const AdsConfigScreen(),
        5 => const EconomyScreen(),
        6 => const AnnouncementScreen(),
        7 => const NotificationsScreen(),
        _ => const AppConfigScreen(),
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile ? 'Admin' : 'Pixel Art Admin',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: flavor.id,
              items: [
                for (final f in kFlavors)
                  DropdownMenuItem(
                    value: f.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: f.brandColor),
                        const SizedBox(width: 8),
                        Text(
                          isMobile ? f.displayName : '${f.displayName} (${f.id})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) state.flavor = flavorById(id);
              },
            ),
          ),
          SizedBox(width: isMobile ? 8 : 16),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AdminAuthService>().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isMobile
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: flavor.brandColor.withAlpha(40),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: flavor.brandColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              flavor.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pixel Art Admin',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < _sections.length; i++)
                    ListTile(
                      leading: Icon(_sections[i].icon),
                      title: Text(_sections[i].label),
                      selected: _index == i,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.pop(context); // Close drawer
                      },
                    ),
                ],
              ),
            )
          : null,
      body: isMobile
          ? activeChild
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final s in _sections)
                      NavigationRailDestination(
                        icon: Icon(s.icon),
                        label: Text(s.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: activeChild),
              ],
            ),
    );
  }
}

