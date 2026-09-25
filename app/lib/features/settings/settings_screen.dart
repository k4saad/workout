import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/preferences_service.dart';

/// The few things worth switching on or off.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final prefs = ref.watch(preferencesProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: Gap.pagePadding,
        children: [
          Text('Reminders', style: t.titleLarge),
          Gap.xs,
          Text(
            'One quiet nudge on evenings the programme plans a session. '
            'Never on a rest day, never on an optional day, and never after '
            'you have already trained.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          if (prefs == null)
            const Skeleton(height: 56)
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs.eveningReminder,
              title: const Text('Evening reminder'),
              subtitle: Text(
                prefs.eveningReminder
                    ? 'At ${prefs.reminderLabel} on training days'
                    : 'Off',
              ),
              onChanged: (on) => ref
                  .read(preferencesProvider.notifier)
                  .set(prefs.copyWith(eveningReminder: on)),
            ),
            if (prefs.eveningReminder)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                subtitle: Text(prefs.reminderLabel),
                trailing: const Icon(Icons.schedule),
                onTap: () => _pickTime(context, ref, prefs),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs.launchQuote,
              title: const Text('A quote to open the day'),
              subtitle: const Text(
                'On the first open of each day, then out of the way. A tap '
                'moves it on sooner.',
              ),
              onChanged: (on) => ref
                  .read(preferencesProvider.notifier)
                  .set(prefs.copyWith(launchQuote: on)),
            ),
          ],

          Gap.xl,
          Text('The gym', style: t.titleLarge),
          Gap.s,
          _Link(
            icon: Icons.fitness_center,
            title: 'Your equipment',
            body:
                'The bars and plates every load is built from, and your '
                'week-12 targets in plates.',
            onTap: () => context.go('/more/settings/gym'),
          ),
          _Link(
            icon: Icons.edit_note,
            title: 'Edit the programme',
            body: 'Sets, reps, rest, and swapping a movement out.',
            onTap: () => context.go('/more/settings/programme'),
          ),
          _Link(
            icon: Icons.folder_outlined,
            title: 'Backup and files',
            body: 'Export, import, and reset to the shipped programme.',
            onTap: () => context.go('/more/settings/files'),
          ),
          _Link(
            icon: Icons.auto_graph,
            title: 'Next cycle',
            body: 'What the week-12 test results seed.',
            onTap: () => context.go('/more/settings/next-cycle'),
          ),
          Gap.xl,
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    Preferences prefs,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: prefs.reminderHour,
        minute: prefs.reminderMinute,
      ),
    );
    if (picked == null) return;
    await ref
        .read(preferencesProvider.notifier)
        .set(
          prefs.copyWith(
            reminderHour: picked.hour,
            reminderMinute: picked.minute,
          ),
        );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textDim),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                Gap.xs,
                Text(
                  body,
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textDim),
        ],
      ),
    );
  }
}
