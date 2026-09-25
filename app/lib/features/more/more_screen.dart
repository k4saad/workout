import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ui/ui.dart';

/// Everything that is not today, this week, the numbers or your body.
///
/// A list, not a grid of icons: in bad light a word you can read beats a
/// pictogram you have to decode.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final library = ref.watch(exerciseLibraryProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: Gap.pagePadding,
        children: [
          _Row(
            icon: Icons.menu_book_outlined,
            title: 'Exercises',
            body: library == null
                ? 'Cues, common errors and a safety note for each'
                : '${library.length} movements, with cues and common errors',
            onTap: () => context.go('/more/exercises'),
          ),
          _Row(
            icon: Icons.directions_run,
            title: 'Cardio',
            body: 'Interval timer for skipping and bag rounds',
            onTap: () => context.go('/more/cardio'),
          ),
          _Row(
            icon: Icons.tune,
            title: 'Settings',
            body: 'Bars and plates, the programme itself, backups, next cycle',
            onTap: () => context.go('/more/settings'),
          ),

          Gap.xl,
          Text(
            'Everything lives on this phone. No account, no server, nothing '
            'syncing in the background. Back it up from Settings.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.crimson),
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
      ),
    );
  }
}
