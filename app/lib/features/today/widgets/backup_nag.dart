import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/settings_providers.dart';
import '../../../core/theme/app_theme.dart';

/// A quiet reminder that the only copy of everything is on this phone.
///
/// It appears once there is something to lose and no recent copy of it, and
/// it disappears the moment you export one. A backup you have never taken is
/// the failure this whole app is one dropped phone away from.
class BackupNag extends ConsumerWidget {
  const BackupNag({super.key, required this.hasTrainingData});

  final bool hasTrainingData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasTrainingData) return const SizedBox.shrink();

    final prefs = ref.watch(preferencesProvider).asData?.value;
    if (prefs == null) return const SizedBox.shrink();

    final today = ref.watch(todayProvider);
    if (!prefs.backupIsStale(today)) return const SizedBox.shrink();

    final days = prefs.daysSinceBackup(today);
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => context.go('/more/settings/files'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warn.withValues(alpha: 0.10),
            border: Border.all(color: AppTheme.warn.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.backup_outlined, color: AppTheme.warn, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days == null
                          ? 'No backup yet'
                          : 'Last backup was $days days ago',
                      style: t.titleMedium?.copyWith(color: AppTheme.warn),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every set you have logged and every photo you have '
                      'taken exists on this phone and nowhere else. It takes '
                      'about a minute. Tap to do it now.',
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.warn),
            ],
          ),
        ),
      ),
    );
  }
}
