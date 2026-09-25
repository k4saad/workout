import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:intl/intl.dart' show DateFormat;

import '../../app/progress_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/media_repository.dart';
import 'progress_screen.dart' show photoHero;

/// One shoot, full size, a pose per page.
///
/// Deleting here deletes the files, not just the rows: these are the only
/// copies, on this phone only.
class ShootViewerScreen extends ConsumerStatefulWidget {
  const ShootViewerScreen({super.key, required this.shootId, this.poseId});

  final String shootId;

  /// The pose to open on: the thumbnail that was tapped.
  final String? poseId;

  @override
  ConsumerState<ShootViewerScreen> createState() => _ShootViewerState();
}

class _ShootViewerState extends ConsumerState<ShootViewerScreen> {
  /// Made once the photos are known, so it can open on the tapped pose.
  PageController? _pages;
  int _page = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
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
      ) ??
      false;

  Future<void> _deletePhoto(ProgressPhoto photo, String poseName) async {
    if (!await _confirm(
      'Delete this photo?',
      'The $poseName photo is deleted from the phone for good. There is no '
          'other copy unless you exported a backup.',
    )) {
      return;
    }
    final media = await ref.read(mediaRepositoryProvider.future);
    await media.deletePhoto(photo.id);
    // The last photo out takes the shoot with it.
    if (await media.tidyEmptyShoots() > 0 && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteShoot() async {
    if (!await _confirm(
      'Delete the whole shoot?',
      'Every photo in it is deleted from the phone for good. There is no '
          'other copy unless you exported a backup.',
    )) {
      return;
    }
    final media = await ref.read(mediaRepositoryProvider.future);
    await media.deleteShoot(widget.shootId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shoots = ref.watch(shootsProvider).asData?.value ?? const [];
    final shoot = shoots.where((s) => s.id == widget.shootId).firstOrNull;
    final poses = ref.watch(posesProvider).asData?.value ?? const [];
    final root = ref.watch(mediaRootProvider).asData?.value;
    final order = {for (final (i, p) in poses.indexed) p.id: i};
    final names = {for (final p in poses) p.id: p.name};
    final photos = [
      ...ref.watch(shootPhotosProvider(widget.shootId)),
    ]..sort((a, b) => (order[a.poseId] ?? 99).compareTo(order[b.poseId] ?? 99));

    if (shoot == null || root == null) {
      return const Scaffold(body: SkeletonPage(cards: 1));
    }
    if (_pages == null && photos.isNotEmpty) {
      final at = photos.indexWhere((p) => p.poseId == widget.poseId);
      _page = at < 0 ? 0 : at;
      _pages = PageController(initialPage: _page);
    }
    final page = _page.clamp(0, photos.isEmpty ? 0 : photos.length - 1);

    // Neighbouring shoots, oldest to newest, for stepping through time.
    final ordered = shoots.reversed.toList();
    final at = ordered.indexWhere((s) => s.id == shoot.id);
    PhotoShoot? step(int by) {
      final i = at + by;
      return i < 0 || i >= ordered.length ? null : ordered[i];
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(DateFormat('EEE d MMMM').format(shoot.shotOn)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'shoot') _deleteShoot();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'shoot', child: Text('Delete the shoot')),
            ],
          ),
        ],
      ),
      body: photos.isEmpty
          ? const EmptyState(
              icon: Icons.photo_outlined,
              title: 'No photos in this shoot',
            )
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => InteractiveViewer(
                      maxScale: 4,
                      child: Center(
                        child: photoHero(
                          photos[i].id,
                          Image.file(
                            MediaRepository.photoFile(
                              root,
                              photos[i].relativePath,
                            ),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.textDim,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              names[photos[page].poseId] ?? photos[page].poseId,
                              style: t.titleMedium,
                            ),
                            Text(
                              [
                                '${page + 1} of ${photos.length}',
                                if (shoot.weekNo case final w?) 'week $w',
                                if (shoot.bodyweightKg case final kg?)
                                  '${kg.toStringAsFixed(1)} kg',
                              ].join(' · '),
                              style: t.bodySmall?.copyWith(
                                color: AppTheme.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete this photo',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePhoto(
                          photos[page],
                          names[photos[page].poseId] ?? 'this',
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: step(-1) == null
                              ? null
                              : () => _open(step(-1)!),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Earlier'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: step(1) == null
                              ? null
                              : () => _open(step(1)!),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Later'),
                              Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Steps to another shoot in place, so back still returns to the list.
  void _open(PhotoShoot s) =>
      context.pushReplacement('/progress/photos/${s.id}');
}
