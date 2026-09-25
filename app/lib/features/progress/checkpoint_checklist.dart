import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/progress_providers.dart';
import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/models/programme.dart';
import '../../domain/progress/checkpoint_review.dart';

/// A checkpoint's lines. The photos, the tape, the scale and the log tick
/// themselves from what is already in the app; the rest tick with a tap.
class CheckpointChecklist extends ConsumerWidget {
  const CheckpointChecklist({super.key, required this.checkpoint});

  final Checkpoint checkpoint;

  static String _source(CheckKind k) => switch (k) {
    CheckKind.photos => 'ticks itself when a shoot has every pose',
    CheckKind.measurements => 'ticks itself when every site is measured',
    CheckKind.weighIn => 'ticks itself with a weigh-in',
    CheckKind.sessionsLogged => 'ticks itself when no session is missing',
  };

  Future<void> _toggle(WidgetRef ref, int index) async {
    try {
      final prefs = await ref.read(preferencesProvider.future);
      await ref
          .read(preferencesProvider.notifier)
          .set(prefs.withTickToggled(checkpoint.week, index));
    } on Object {
      // Nowhere to keep the tick; the line simply stays as it was.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final items =
        ref.watch(checkpointReviewProvider(checkpoint.week)).asData?.value ??
        [
          for (final (i, text) in checkpoint.items.indexed)
            CheckItem(
              index: i,
              text: text,
              done: false,
              auto: checkpoint.autoFor(i),
            ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: item.auto == null ? () => _toggle(ref, item.index) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 10),
                      child: Icon(
                        item.done
                            ? Icons.check_circle
                            : item.auto != null
                            ? Icons.radio_button_unchecked
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: item.done ? AppTheme.good : AppTheme.textDim,
                        semanticLabel: item.done ? 'done' : 'not done',
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.text,
                            style: t.bodyMedium!.copyWith(
                              color: item.done
                                  ? AppTheme.textDim
                                  : AppTheme.text,
                            ),
                          ),
                          if (item.auto != null && !item.done)
                            Text(
                              _source(item.auto!),
                              style: t.bodySmall!.copyWith(
                                color: AppTheme.textFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "3 of 5", for a checkpoint's header.
class CheckpointCount extends ConsumerWidget {
  const CheckpointCount({super.key, required this.week});

  final int week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(checkpointReviewProvider(week)).asData?.value;
    if (items == null) return const SizedBox.shrink();
    final done = items.where((i) => i.done).length;
    final all = done == items.length;
    return Text(
      all ? '✓ all done' : '$done of ${items.length}',
      style: Theme.of(context).textTheme.labelLarge!
          .copyWith(color: all ? AppTheme.good : AppTheme.textDim),
    );
  }
}
