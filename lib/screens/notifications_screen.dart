import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/admin_state.dart';

/// Push campaign helper. Apps subscribe to one FCM topic per flavor
/// (`pixelart_<flavor>`); sending happens from the Firebase console, which
/// needs no server code. This screen documents the flow and hands you the
/// topic name.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flavor = context.watch<AdminState>().flavor;
    final topic = 'pixelart_${flavor.id}';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${flavor.displayName} — push notifications',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Every install of ${flavor.displayName} subscribes to the FCM topic '
          'below. Campaigns are composed and sent from the Firebase console '
          '(no server needed).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tag_rounded),
            title: SelectableText(
              topic,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('FCM topic for this flavor'),
            trailing: IconButton(
              tooltip: 'Copy topic',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: topic));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Topic copied')),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('How to send a campaign',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _Step(
          number: 1,
          text: 'Open the Firebase console → project om108-5c015 → '
              'Engage → Messaging → "New campaign" → Notifications.',
        ),
        const _Step(
          number: 2,
          text: 'Write the notification title and text '
              '(e.g. "New artwork pack just dropped!").',
        ),
        const _Step(
          number: 3,
          text: 'Under Target, choose "Topic" and enter the topic above — '
              'this reaches only this flavor\'s users.',
        ),
        const _Step(
          number: 4,
          text: 'Schedule or send now. Delivery/open stats appear in the '
              'Messaging dashboard.',
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Tip: pair a campaign with an in-app Announcement so users who '
              'have notifications disabled still see the news.',
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 11, child: Text('$number')),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
