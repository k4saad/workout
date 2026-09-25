import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:intl/intl.dart' show DateFormat;

import '../../app/progress_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/media_repository.dart';
import '../common/widgets.dart';
import 'widgets/compare_widgets.dart';

/// Progress photos: every shoot by week, any two side by side, and each
/// pose as a time-lapse.
///
/// Everything here lives in app-private storage. Nothing on this screen,
/// or anywhere in the app, can send a photo anywhere.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(currentWeekProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Photos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Timeline'),
              Tab(text: 'Compare'),
              Tab(text: 'Time-lapse'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/capture?week=$week'),
          icon: const Icon(Icons.photo_camera),
          label: const Text('New shoot'),
        ),
        body: const TabBarView(
          children: [_Timeline(), _Compare(), _TimeLapse()],
        ),
      ),
    );
  }
}

/// Width over height for a photo, from what was stored; 9:16 when unknown.
double photoAspect(ProgressPhoto? p) =>
    p == null || p.width <= 0 || p.height <= 0 ? 9 / 16 : p.width / p.height;

String _kg(double kg) => '${kg.toStringAsFixed(1)} kg';

String _signedKg(double d) =>
    '${d >= 0 ? '+' : '−'}${d.abs().toStringAsFixed(1)} kg';

class _NoShoots extends StatelessWidget {
  const _NoShoots();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.photo_library_outlined,
    title: 'No shoots yet',
    body:
        'Take the baseline four before week 1. Week 1 cannot be shot '
        'afterwards, and every later shoot lines up against it.\n\n'
        'These photos never leave this phone.',
  );
}

// ----------------------------------------------------------------- timeline

class _Timeline extends ConsumerWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shootsAsync = ref.watch(shootsProvider);
    final bundle = ref.watch(bundleProvider).asData?.value;
    final stats = ref.watch(mediaStatsProvider).asData?.value;

    return shootsAsync.when(
      loading: () => const SkeletonPage(cards: 2),
      error: (e, _) =>
          AsyncScaffoldBody(loading: false, error: e, child: const SizedBox()),
      data: (shoots) {
        if (shoots.isEmpty) return const _NoShoots();
        final first = shoots.last;

        // Newest week first; within a week, newest shoot first.
        final byWeek = <int, List<PhotoShoot>>{};
        for (final s in shoots) {
          final w = s.weekNo ?? bundle?.calendar.weekNumberFor(s.shotOn) ?? 0;
          (byWeek[w] ??= []).add(s);
        }
        final weeks = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (stats != null) _StorageBar(stats: stats),
            for (final w in weeks) ...[
              _WeekHeader(
                week: w,
                checkpoint: bundle?.programme.checkpointForWeek(w) != null,
              ),
              for (final s in byWeek[w]!) ...[
                _ShootCard(shoot: s, first: first),
                Gap.m,
              ],
            ],
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.week, required this.checkpoint});

  final int week;
  final bool checkpoint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(
      children: [
        Text(
          week < 1 ? 'BEFORE WEEK 1' : 'WEEK $week',
          style: AppTheme.overline,
        ),
        if (checkpoint) ...[
          const SizedBox(width: 8),
          const Icon(Icons.flag_rounded, size: 14, color: AppTheme.crimson),
          const SizedBox(width: 4),
          Text(
            'checkpoint',
            style: AppTheme.overline.copyWith(color: AppTheme.crimson),
          ),
        ],
      ],
    ),
  );
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.stats});

  final MediaStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final warn = stats.isNearBudget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppTheme.textDim),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${stats.photoCount} photos · ${stats.readable}, on this '
                'phone only',
                style: t.bodySmall?.copyWith(color: AppTheme.textDim),
              ),
            ),
            Text(
              '${warn ? '⚠ ' : ''}of ${stats.budgetReadable}',
              style: t.bodySmall?.copyWith(
                color: warn ? AppTheme.warn : AppTheme.textDim,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: stats.fraction,
            minHeight: 3,
            backgroundColor: AppTheme.outlineSoft,
            valueColor: AlwaysStoppedAnimation(
              warn ? AppTheme.warn : AppTheme.textDim,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShootCard extends ConsumerWidget {
  const _ShootCard({required this.shoot, required this.first});

  final PhotoShoot shoot;
  final PhotoShoot first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final photos = ref.watch(shootPhotosProvider(shoot.id));
    final poses = ref.watch(posesProvider).asData?.value ?? const [];
    final root = ref.watch(mediaRootProvider).asData?.value;
    final byPose = {for (final p in photos) p.poseId: p};
    final kg = shoot.bodyweightKg;
    final since = kg != null && first.bodyweightKg != null && first != shoot
        ? kg - first.bodyweightKg!
        : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      onTap: () => context.push('/progress/photos/${shoot.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEE d MMMM').format(shoot.shotOn),
                  style: t.titleMedium,
                ),
              ),
              if (kg != null) Text(_kg(kg), style: AppTheme.numeric(18)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  poses.isEmpty
                      ? '${photos.length} photos'
                      : photos.length >= poses.length
                      ? 'all ${poses.length} poses'
                      : '${photos.length} of ${poses.length} poses',
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
              ),
              if (since != null)
                Text(
                  '${since >= 0 ? '▲' : '▼'} ${_signedKg(since)} since the first',
                  style: t.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
            ],
          ),
          Gap.s,
          Row(
            children: [
              for (final (i, pose) in poses.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: photoAspect(byPose[pose.id]),
                    child: _Thumb(
                      photo: byPose[pose.id],
                      root: root,
                      label: pose.name,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A photo's thumbnail, or a labelled gap where a pose was not taken.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.root, required this.label});

  final ProgressPhoto? photo;
  final Directory? root;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = root;
    final p = photo;
    Widget child;
    if (p == null || r == null) {
      child = Container(
        color: AppTheme.surfaceHigh,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: Text(
          p == null ? '–\n$label' : '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppTheme.textFaint),
        ),
      );
    } else {
      final thumb = MediaRepository.thumbFile(r, p.relativePath);
      child = Image.file(
        thumb.existsSync()
            ? thumb
            : MediaRepository.photoFile(r, p.relativePath),
        fit: BoxFit.cover,
        cacheWidth: 360,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppTheme.surfaceHigh,
          child: Icon(Icons.broken_image_outlined, color: AppTheme.textDim),
        ),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: child);
  }
}

// -------------------------------------------------------------- pose picker

class _PoseChips extends ConsumerWidget {
  const _PoseChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poses = ref.watch(posesProvider).asData?.value ?? const [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final pose in poses)
          ChoiceChip(
            label: Text(pose.name),
            selected: pose.id == selected,
            onSelected: (_) => onSelected(pose.id),
          ),
      ],
    );
  }
}

/// A photo with its shoot, for captions: "Week 4 · 51.2 kg".
typedef _Framed = ({ProgressPhoto photo, PhotoShoot? shoot});

List<_Framed> _framed(WidgetRef ref, String poseId) {
  final shoots = {
    for (final s in ref.watch(shootsProvider).asData?.value ?? const [])
      s.id: s,
  };
  return [
    for (final p in ref.watch(posePhotosProvider(poseId)))
      (photo: p, shoot: shoots[p.shootId]),
  ];
}

String _caption(_Framed f, {bool long = false}) {
  final s = f.shoot;
  final date = DateFormat(long ? 'd MMM yyyy' : 'd MMM')
      .format(s?.shotOn ?? f.photo.takenAt);
  return [
    if (s?.weekNo case final w?) 'Week $w',
    date,
    if (s?.bodyweightKg case final kg?) _kg(kg),
  ].join(' · ');
}

// ------------------------------------------------------------------ compare

class _Compare extends ConsumerStatefulWidget {
  const _Compare();

  @override
  ConsumerState<_Compare> createState() => _CompareState();
}

class _CompareState extends ConsumerState<_Compare> {
  String? _poseId;
  String? _beforeId;
  String? _afterId;
  bool _wipe = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final poses = ref.watch(posesProvider).asData?.value ?? const [];
    final root = ref.watch(mediaRootProvider).asData?.value;
    if (poses.isEmpty || root == null) return const SkeletonPage(cards: 1);
    final poseId = _poseId ?? poses.first.id;
    final all = _framed(ref, poseId);

    if ((ref.watch(shootsProvider).asData?.value ?? const []).isEmpty) {
      return const _NoShoots();
    }

    // Any two shoots; the first and the latest unless he picks.
    _Framed? pick(String? id, _Framed? fallback) =>
        all.where((f) => f.photo.id == id).firstOrNull ?? fallback;
    final before = pick(_beforeId, all.firstOrNull);
    final after = pick(_afterId, all.lastOrNull);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _PoseChips(
          selected: poseId,
          onSelected: (id) => setState(() {
            _poseId = id;
            _beforeId = _afterId = null;
          }),
        ),
        Gap.m,
        if (all.length < 2 || before == null || after == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              all.isEmpty
                  ? 'No photos of this pose yet.'
                  : 'One shot of this pose so far. Comparing needs two — '
                        'the next checkpoint makes the second.',
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _Picker(
                  label: 'Before',
                  value: _caption(before),
                  onTap: () => _choose(all, before, (id) => _beforeId = id),
                ),
              ),
              Gap.s,
              Expanded(
                child: _Picker(
                  label: 'After',
                  value: _caption(after),
                  onTap: () => _choose(all, after, (id) => _afterId = id),
                ),
              ),
            ],
          ),
          Gap.m,
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Wipe')),
              ButtonSegment(value: false, label: Text('Side by side')),
            ],
            selected: {_wipe},
            onSelectionChanged: (s) => setState(() => _wipe = s.first),
          ),
          Gap.m,
          if (_wipe)
            AspectRatio(
              aspectRatio: photoAspect(after.photo),
              child: WipeCompare(
                key: ValueKey('${before.photo.id}-${after.photo.id}'),
                before: MediaRepository.photoFile(
                  root,
                  before.photo.relativePath,
                ),
                after: MediaRepository.photoFile(
                  root,
                  after.photo.relativePath,
                ),
                beforeLabel: _caption(before),
                afterLabel: _caption(after),
              ),
            )
          else
            SideBySide(
              before: MediaRepository.photoFile(
                root,
                before.photo.relativePath,
              ),
              after: MediaRepository.photoFile(root, after.photo.relativePath),
              beforeCaption: _caption(before),
              afterCaption: _caption(after),
              aspectRatio: photoAspect(after.photo),
            ),
          if (_between(before, after) case final text?) ...[
            Gap.m,
            Text(
              text,
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ],
      ],
    );
  }

  static String? _between(_Framed a, _Framed b) {
    final days = b.photo.takenAt.difference(a.photo.takenAt).inDays;
    final weeks = (days / 7).round();
    final kgA = a.shoot?.bodyweightKg, kgB = b.shoot?.bodyweightKg;
    final parts = [
      if (weeks > 0) '$weeks week${weeks == 1 ? '' : 's'} apart',
      if (kgA != null && kgB != null) _signedKg(kgB - kgA),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _choose(
    List<_Framed> all,
    _Framed current,
    void Function(String id) set,
  ) async {
    final id = await showAppSheet<String>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in all.reversed)
            ListTile(
              minTileHeight: 52,
              title: Text(_caption(f, long: true)),
              trailing: f.photo.id == current.photo.id
                  ? const Icon(Icons.check, color: AppTheme.crimson)
                  : null,
              onTap: () => Navigator.pop(context, f.photo.id),
            ),
        ],
      ),
    );
    if (id != null) setState(() => set(id));
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      radius: AppRadius.m,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppTheme.overline),
                const SizedBox(height: 2),
                Text(value, maxLines: 2, style: t.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.expand_more, color: AppTheme.textDim),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- time-lapse

class _TimeLapse extends ConsumerStatefulWidget {
  const _TimeLapse();

  @override
  ConsumerState<_TimeLapse> createState() => _TimeLapseState();
}

class _TimeLapseState extends ConsumerState<_TimeLapse> {
  String? _poseId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final poses = ref.watch(posesProvider).asData?.value ?? const [];
    final root = ref.watch(mediaRootProvider).asData?.value;
    if (poses.isEmpty || root == null) return const SkeletonPage(cards: 1);
    if ((ref.watch(shootsProvider).asData?.value ?? const []).isEmpty) {
      return const _NoShoots();
    }
    final poseId = _poseId ?? poses.first.id;
    final all = _framed(ref, poseId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _PoseChips(
          selected: poseId,
          onSelected: (id) => setState(() => _poseId = id),
        ),
        Gap.m,
        if (all.length < 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'A time-lapse needs two shots of a pose. It grows with every '
              'checkpoint.',
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
            ),
          )
        else
          Flipbook(
            key: ValueKey(poseId),
            frames: [
              for (final f in all)
                MediaRepository.photoFile(root, f.photo.relativePath),
            ],
            captions: [for (final f in all) _caption(f, long: true)],
            aspectRatio: photoAspect(all.last.photo),
          ),
      ],
    );
  }
}
