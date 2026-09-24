import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/upgrade_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../data/programme_repository.dart';

/// Once, after a new release replaced the phone's programme or kit: what
/// changed, what was kept, and where the old copy is. Dismissed, it is gone.
class UpgradeNotice extends ConsumerWidget {
  const UpgradeNotice({super.key});

  /// The words for [up]: (tone, title, body).
  static (Tone, String, String) describe(ProgrammeUpgrade up) {
    if (up.programmeUnreadable) {
      return (
        Tone.warn,
        'Programme file could not be read',
        'The shipped programme is loaded instead, and every logged set is '
            'safe. The unreadable file is kept as ${up.programmeBackup}.',
      );
    }
    if (up.replacedProgramme) {
      final kept = up.keptStartDate == null
          ? 'Your start date is kept.'
          : 'Start date kept: '
                '${DateFormat('EEEE d MMMM').format(up.keptStartDate!)}.';
      final copy = up.programmeWasEdited
          ? 'the copy you had edited is saved on the phone'
          : 'the old copy is saved on the phone';
      final kit = up.replacedInventory
          ? ' The kit is the definitive one now.'
          : '';
      return (
        Tone.info,
        'Programme updated to revision ${up.programmeTo}',
        '$kept Every logged set is untouched, and $copy '
            '(${up.programmeBackup}).$kit',
      );
    }
    if (up.inventoryUnreadable) {
      return (
        Tone.warn,
        'Equipment file could not be read',
        'The shipped kit is loaded instead. The unreadable file is kept as '
            '${up.inventoryBackup}.',
      );
    }
    return (
      Tone.info,
      'Equipment updated',
      'Every load now comes from the definitive kit. Your old list is kept '
          'as ${up.inventoryBackup}.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final up = ref.watch(upgradeNoticeProvider).asData?.value;
    if (up == null) return const SizedBox.shrink();
    final (tone, title, body) = describe(up);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ToneBanner(
        tone: tone,
        icon: tone == Tone.info ? Icons.system_update_alt : null,
        title: title,
        body: body,
        trailing: IconButton(
          tooltip: 'Dismiss',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.close, color: AppTheme.textDim),
          onPressed: () => ref.read(upgradeNoticeProvider.notifier).dismiss(),
        ),
      ),
    );
  }
}
