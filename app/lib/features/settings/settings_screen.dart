import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';

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
            'From the planner, two weeks ahead: a class 15 minutes before '
            'with its room, work when it is time to leave, a session half an '
            'hour before. Nothing for a class you skipped, a session already '
            'done or a rest day.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          if (prefs == null)
            const Skeleton(height: 56)
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.school_outlined),
              value: prefs.remindClasses,
              title: const Text('Classes'),
              subtitle: const Text('15 minutes before, with the room'),
              onChanged: (on) => ref
                  .read(preferencesProvider.notifier)
                  .set(prefs.copyWith(remindClasses: on)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.work_outline),
              value: prefs.remindWork,
              title: const Text('Work'),
              subtitle: const Text('When to leave: 30 minutes to get there'),
              onChanged: (on) => ref
                  .read(preferencesProvider.notifier)
                  .set(prefs.copyWith(remindWork: on)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fitness_center),
              value: prefs.remindSessions,
              title: const Text('Training sessions'),
              subtitle: const Text('Half an hour before'),
              onChanged: (on) => ref
                  .read(preferencesProvider.notifier)
                  .set(prefs.copyWith(remindSessions: on)),
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
