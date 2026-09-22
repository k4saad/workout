import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/exercise_providers.dart';
import '../../app/progress_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/database.dart';
import '../../domain/models/exercise.dart';
import '../common/widgets.dart';
import 'widgets/clip_player.dart';

/// Everything known about one movement.
///
/// Reachable in one tap from inside the session runner, and returning to the
/// exact set you were on. A demo you have to leave the session to find does
/// not get watched.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).asData?.value;
    if (library == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ex = library.resolve(exerciseId);
    final clips = ref.watch(clipsProvider(exerciseId)).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: ListView(
        padding: Gap.pagePadding,
        children: [
          if (ex.media.hasStill) _Still(path: ex.media.still!),

          Gap.m,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ex.pattern.isNotEmpty) InfoChip(label: ex.pattern),
              for (final m in ex.primaryMuscles)
                InfoChip(label: m, emphasis: true),
              for (final m in ex.secondaryMuscles) InfoChip(label: m),
              for (final e in ex.equipment)
                InfoChip(label: e, icon: Icons.fitness_center),
            ],
          ),

          if (ex.media.hasVideo) ...[
            Gap.m,
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openVideo(ex),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Watch demo'),
              ),
            ),
          ] else ...[
            Gap.m,
            _NoVideoNote(exerciseId: ex.id),
          ],

          if (ex.soloSafety != null) ...[
            Gap.l,
            _SafetyPanel(text: ex.soloSafety!),
          ],

          if (ex.cues.isNotEmpty) ...[
            Gap.l,
            _Section(title: 'Cues', items: ex.cues, bullet: '•'),
          ],

          if (ex.commonErrors.isNotEmpty) ...[
            Gap.l,
            _Section(
              title: 'What usually goes wrong',
              items: ex.commonErrors,
              bullet: '✗',
              colour: AppTheme.warn,
            ),
          ],

          if (ex.equipmentNote != null) ...[
            Gap.l,
            _Note(title: 'In your gym', body: ex.equipmentNote!),
          ],
          if (ex.progressionNote != null) ...[
            Gap.m,
            _Note(title: 'Progressing it', body: ex.progressionNote!),
          ],

          if (ex.substitutes.isNotEmpty) ...[
            Gap.l,
            Text(
              'If this one is not working today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in ex.substitutes)
                  ActionChip(
                    label: Text(library.resolve(id).name),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExerciseDetailScreen(exerciseId: id),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          Gap.l,
          _ClipsSection(exerciseId: ex.id, clips: clips),
          Gap.xl,
        ],
      ),
    );
  }

  Future<void> _openVideo(Exercise ex) async {
    var url = ex.media.youtubeUrl!;
    if (ex.media.youtubeStartSec > 0 && !url.contains('t=')) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}t=${ex.media.youtubeStartSec}';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Still extends StatelessWidget {
  const _Still({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _NoVideoNote extends StatelessWidget {
  const _NoVideoNote({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'No demo link yet. These are filled in by hand rather than guessed — '
        'an invented URL cannot be verified, and a wrong demo teaches the '
        'wrong movement.\n\n'
        'Add one under `$exerciseId` in docs/05-demo-checklist.md.',
        style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
      ),
    );
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.10),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, color: AppTheme.warn),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Training alone',
                  style: t.titleMedium?.copyWith(color: AppTheme.warn),
                ),
                Gap.xs,
                Text(text, style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.bullet,
    this.colour,
  });

  final String title;
  final List<String> items;
  final String bullet;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleLarge),
        Gap.s,
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Text(
                    bullet,
                    style: TextStyle(color: colour ?? AppTheme.textDim),
                  ),
                ),
                Expanded(child: Text(item, style: t.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium),
            Gap.xs,
            Text(body, style: t.bodyMedium?.copyWith(color: AppTheme.textDim)),
          ],
        ),
      ),
    );
  }
}

/// Your own filmed sets.
///
/// For a lifter with no coach this is the most valuable media in the app.
/// Week 1 against week 8 catches a squat depth drifting or bench elbows
/// flaring in a way no stock demo can.
class _ClipsSection extends ConsumerWidget {
  const _ClipsSection({required this.exerciseId, required this.clips});

  final String exerciseId;
  final List<FormClip> clips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final media = ref.watch(mediaRepositoryProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your form', style: t.titleLarge),
        Gap.xs,
        Text(
          'Prop the phone on the bench and film one working set from the '
          'side. Compare week 1 with week 8 — that is worth more than '
          'any stock demo when nobody is watching you lift.',
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
        Gap.m,
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: media == null ? null : () => _record(context, ref),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Film a set'),
          ),
        ),
        if (clips.isNotEmpty && media != null) ...[
          Gap.m,
          for (final clip in clips)
            FutureBuilder<File>(
              future: media.fileFor(clip.relativePath),
              builder: (context, snap) {
                final file = snap.data;
                if (file == null || !file.existsSync()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipTile(
                    file: file,
                    caption: DateFormat('d MMM yyyy').format(clip.recordedAt),
                    onDelete: () async {
                      await media.deleteClip(clip.id);
                      ref.invalidate(clipsProvider(exerciseId));
                    },
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final shot = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
      preferredCameraDevice: CameraDevice.rear,
    );
    if (shot == null) return;

    final media = await ref.read(mediaRepositoryProvider.future);
    await media.saveClip(exerciseId: exerciseId, source: File(shot.path));

    // The picker's temp file is NOT app-private; remove it.
    final tmp = File(shot.path);
    if (tmp.existsSync()) await tmp.delete();

    ref.invalidate(clipsProvider(exerciseId));
    ref.invalidate(mediaStatsProvider);
  }
}
