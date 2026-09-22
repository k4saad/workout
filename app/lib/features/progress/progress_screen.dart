import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/progress_providers.dart';
import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../data/media_repository.dart';
import '../common/widgets.dart';
import 'widgets/compare_widgets.dart';

/// The progress gallery: shoots, poses, comparisons and measurements.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shoots = ref.watch(shootsProvider);
    final poses = ref.watch(posesProvider);
    final stats = ref.watch(mediaStatsProvider).asData?.value;
    final week = ref.watch(currentWeekProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Shoots'),
              Tab(text: 'Compare'),
              Tab(text: 'Measure'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/capture?week=$week'),
          icon: const Icon(Icons.photo_camera),
          label: const Text('New shoot'),
        ),
        body: TabBarView(
          children: [
            _ShootsTab(shoots: shoots, stats: stats),
            _CompareTab(poses: poses),
            const _MeasureTab(),
          ],
        ),
      ),
    );
  }
}

class _ShootsTab extends ConsumerWidget {
  const _ShootsTab({required this.shoots, required this.stats});

  final AsyncValue<List<PhotoShoot>> shoots;
  final MediaStats? stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return shoots.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          AsyncScaffoldBody(loading: false, error: e, child: const SizedBox()),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 48,
                  color: AppTheme.textDim,
                ),
                Gap.m,
                Text('No shoots yet', style: t.titleLarge),
                Gap.s,
                Text(
                  'Take the baseline four this week. You cannot shoot week 1 '
                  'retroactively, and the ghost overlay needs a first frame '
                  'to line up against.\n\n'
                  'These photos never leave this phone.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: Gap.pagePadding,
          children: [
            if (stats != null) _StorageBar(stats: stats!),
            Gap.m,
            for (final shoot in list) _ShootCard(shoot: shoot),
            Gap.xl,
          ],
        );
      },
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.stats});

  final MediaStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colour = stats.isOverBudget
        ? AppTheme.warn
        : stats.isNearBudget
        ? AppTheme.warn
        : AppTheme.moss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${stats.photoCount} photos · ${stats.readable}',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            const Spacer(),
            Text(
              'of ${stats.budgetReadable}',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: stats.fraction,
            minHeight: 4,
            backgroundColor: AppTheme.outline,
            valueColor: AlwaysStoppedAnimation(colour),
          ),
        ),
      ],
    );
  }
}

class _ShootCard extends ConsumerWidget {
  const _ShootCard({required this.shoot});

  final PhotoShoot shoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final photos = ref.watch(shootPhotosProvider(shoot.id)).asData?.value ?? [];
    final media = ref.watch(mediaRepositoryProvider).asData?.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('d MMMM yyyy').format(shoot.shotOn),
                      style: t.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete shoot',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: media == null
                        ? null
                        : () => _confirmDelete(context, ref, media),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (shoot.weekNo != null)
                    InfoChip(label: 'week ${shoot.weekNo}'),
                  if (shoot.bodyweightKg != null)
                    InfoChip(label: '${shoot.bodyweightKg} kg'),
                  InfoChip(label: '${photos.length} photos'),
                ],
              ),
              if (photos.isNotEmpty && media != null) ...[
                Gap.m,
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) =>
                        _Thumb(photo: photos[i], media: media),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MediaRepository media,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete this shoot?'),
        content: const Text(
          'Every photo in it is deleted from the phone permanently. There is '
          'no copy anywhere else unless you have exported a backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await media.deleteShoot(shoot.id);
    ref.invalidate(shootsProvider);
    ref.invalidate(mediaStatsProvider);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.media});

  final ProgressPhoto photo;
  final MediaRepository media;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: media.fileFor(photo.relativePath),
      builder: (context, snap) {
        final file = snap.data;
        if (file == null || !file.existsSync()) {
          return Container(
            width: 90,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppTheme.textDim,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 90, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _CompareTab extends ConsumerStatefulWidget {
  const _CompareTab({required this.poses});

  final AsyncValue<List<PhotoPose>> poses;

  @override
  ConsumerState<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends ConsumerState<_CompareTab> {
  String? _poseId;
  bool _wipe = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final poses = widget.poses.asData?.value ?? [];
    if (poses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final poseId = _poseId ?? poses.first.id;
    final photos = ref.watch(posePhotosProvider(poseId)).asData?.value ?? [];
    final media = ref.watch(mediaRepositoryProvider).asData?.value;

    return ListView(
      padding: Gap.pagePadding,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pose in poses)
              ChoiceChip(
                label: Text(pose.name),
                selected: pose.id == poseId,
                onSelected: (_) => setState(() => _poseId = pose.id),
              ),
          ],
        ),
        Gap.m,
        if (photos.length < 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              photos.isEmpty
                  ? 'No photos of this pose yet.'
                  : 'One photo so far. Comparison needs two — come back '
                        'at the week-4 checkpoint.',
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
            ),
          )
        else if (media != null) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Wipe')),
              ButtonSegment(value: false, label: Text('Side by side')),
            ],
            selected: {_wipe},
            onSelectionChanged: (s) => setState(() => _wipe = s.first),
          ),
          Gap.m,
          FutureBuilder<List<File>>(
            future: Future.wait([
              media.fileFor(photos.first.relativePath),
              media.fileFor(photos.last.relativePath),
            ]),
            builder: (context, snap) {
              final files = snap.data;
              if (files == null || files.any((f) => !f.existsSync())) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final firstLabel = DateFormat('d MMM')
                  .format(photos.first.takenAt);
              final lastLabel = DateFormat('d MMM').format(photos.last.takenAt);
              return _wipe
                  ? AspectRatio(
                      aspectRatio: 3 / 4,
                      child: WipeCompare(
                        before: files[0],
                        after: files[1],
                        beforeLabel: firstLabel,
                        afterLabel: lastLabel,
                      ),
                    )
                  : SideBySide(
                      before: files[0],
                      after: files[1],
                      beforeCaption: firstLabel,
                      afterCaption: lastLabel,
                    );
            },
          ),
          Gap.l,
          Text('Every shot of this pose', style: t.titleMedium),
          Gap.s,
          FutureBuilder<List<File>>(
            future: Future.wait(
              photos.map((p) => media.fileFor(p.relativePath)),
            ),
            builder: (context, snap) {
              final files = snap.data;
              if (files == null) return const SizedBox.shrink();
              return Flipbook(
                frames: files.where((f) => f.existsSync()).toList(),
                captions: photos
                    .map((p) => DateFormat('d MMM yyyy').format(p.takenAt))
                    .toList(),
              );
            },
          ),
        ],
        Gap.xl,
      ],
    );
  }
}

class _MeasureTab extends ConsumerWidget {
  const _MeasureTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: Gap.pagePadding,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The waist is the one that matters', style: t.titleMedium),
                Gap.s,
                Text(
                  'Expect it to grow a little — you are gaining weight. '
                  'More than 3 cm across twelve weeks means the surplus is '
                  'too big: cut 200 kcal.\n\n'
                  'Same time of day, same tape tension, relaxed and exhaled.',
                  style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
        ),
        Gap.l,
        for (final site in MeasurementSite.values) _MeasurementRow(site: site),
        Gap.xl,
      ],
    );
  }
}

class _MeasurementRow extends ConsumerWidget {
  const _MeasurementRow({required this.site});

  final MeasurementSite site;

  static String label(MeasurementSite s) => switch (s) {
    MeasurementSite.waist => 'Waist',
    MeasurementSite.chest => 'Chest',
    MeasurementSite.upperArm => 'Upper arm',
    MeasurementSite.thigh => 'Thigh',
    MeasurementSite.neck => 'Neck',
    MeasurementSite.hips => 'Hips',
    MeasurementSite.calf => 'Calf',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final rows = ref.watch(measurementsProvider(site)).asData?.value ?? [];
    final latest = rows.isEmpty ? null : rows.last;
    final first = rows.isEmpty ? null : rows.first;
    final delta = (latest != null && first != null && rows.length > 1)
        ? latest.cm - first.cm
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label(site), style: t.titleMedium),
                if (latest != null)
                  Text(
                    '${latest.cm} cm'
                    '${delta != null ? '  (${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)})' : ''}',
                    style: t.bodyMedium?.copyWith(
                      color: site == MeasurementSite.waist && (delta ?? 0) > 3
                          ? AppTheme.warn
                          : AppTheme.textDim,
                    ),
                  )
                else
                  Text(
                    'not measured',
                    style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => _enter(context, ref),
              child: const Text('Enter'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(label(site)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'cm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await ref
        .read(databaseProvider)
        .upsertMeasurement(ref.read(todayProvider), site, value);
    ref.invalidate(measurementsProvider(site));
  }
}
