import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/editor_providers.dart';
import '../../app/settings_providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/backup_service.dart';
import '../../data/programme_editor_service.dart';
import '../../domain/programme/programme_diff.dart';
import '../editor/widgets/problem_strip.dart';

/// Getting the programme and the logs on and off the phone.
///
/// Everything here is manual and explicit. Nothing syncs, nothing uploads on
/// its own, and the only way a progress photo leaves this device is you
/// pressing a button and choosing where it goes.
class ProgrammeFileScreen extends ConsumerStatefulWidget {
  const ProgrammeFileScreen({super.key});

  @override
  ConsumerState<ProgrammeFileScreen> createState() =>
      _ProgrammeFileScreenState();
}

class _ProgrammeFileScreenState extends ConsumerState<ProgrammeFileScreen> {
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Programme file')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: Gap.pagePadding,
          children: [
            if (_status != null) ...[_StatusLine(text: _status!), Gap.m],
            if (_busy) ...[const LinearProgressIndicator(), Gap.m],

            Text('The programme', style: t.titleLarge),
            Gap.s,
            Text(
              'A single JSON file. Readable on the PC, diffable in git, and '
              'the only thing that decides what the app asks you to lift.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            _Action(
              icon: Icons.upload_file_outlined,
              title: 'Export programme',
              body: 'Write it out and choose where it goes.',
              onTap: _exportProgramme,
            ),
            _Action(
              icon: Icons.download_outlined,
              title: 'Import programme',
              body: 'Pick a file. You see exactly what would change first.',
              onTap: _importProgramme,
            ),
            _Action(
              icon: Icons.restore,
              title: 'Reset to shipped programme',
              body: 'Throws away every edit and re-copies the original.',
              onTap: _reset,
              destructive: true,
            ),

            Gap.xl,
            Text('Everything else', style: t.titleLarge),
            Gap.s,
            Text(
              'Sessions, sets, weigh-ins, measurements, progress photos and '
              'form clips, in one zip. This is the file that means a dropped '
              'phone does not end the project.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            _Action(
              icon: Icons.archive_outlined,
              title: 'Export full backup',
              body:
                  'Includes your progress photos — choose the destination '
                  'with that in mind.',
              onTap: _exportBackup,
            ),
            _Action(
              icon: Icons.settings_backup_restore,
              title: 'Restore from backup',
              body: 'Replaces everything currently on the phone.',
              onTap: _restoreBackup,
              destructive: true,
            ),
            Gap.xl,
          ],
        ),
      ),
    );
  }

  void _say(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<T?> _run<T>(Future<T> Function() work) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      return await work();
    } on Object catch (e) {
      _say('$e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- programme -------------------------------------------------------

  Future<void> _exportProgramme() => _run(() async {
    final service = await ref.read(editorServiceProvider.future);
    final dir = await getApplicationDocumentsDirectory();
    final name =
        'keller-programme-'
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
    final file = await service.exportTo(File(p.join(dir.path, 'export', name)));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Keller Twelve programme',
      ),
    );
    _say('Exported $name.');
  });

  Future<void> _importProgramme() => _run(() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final service = await ref.read(editorServiceProvider.future);
    final preview = await service.inspectImport(File(path));
    if (!mounted) return;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _ImportSheet(preview: preview),
    );
    if (apply != true) return;

    await ref
        .read(programmeEditControllerProvider.notifier)
        .applyImport(preview.incoming);
    _say('Imported. ${preview.diff.summary}');
  });

  Future<void> _reset() => _run(() async {
    final ok = await _confirm(
      title: 'Reset to the shipped programme?',
      body:
          'Every edit you have made to the programme is discarded and the '
          'original twelve weeks come back.\n\n'
          'Your logs, photos and measurements are not touched.',
      action: 'Reset',
    );
    if (!ok) return;
    await ref.read(programmeEditControllerProvider.notifier).resetToShipped();
    _say('Back to the shipped programme.');
  });

  // ---- backup ----------------------------------------------------------

  Future<void> _exportBackup() => _run(() async {
    final backup = ref.read(backupServiceProvider);
    final manifest = await backup.buildManifest();
    if (!mounted) return;

    final ok = await _confirm(
      title: 'Export everything?',
      body:
          'The zip will contain ${manifest.summary}, plus your form clips '
          'and the programme file.\n\n'
          'Progress photos are in there. Whatever you share it with can read '
          'them, so pick the destination deliberately.',
      action: 'Export',
    );
    if (!ok) return;

    final dir = await getApplicationDocumentsDirectory();
    final name = BackupService.suggestedFileName(DateTime.now());
    final file = await backup.export(File(p.join(dir.path, 'export', name)));

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Keller Twelve backup'),
    );
    await ref.read(preferencesProvider.notifier).markBackedUp(DateTime.now());
    _say('Exported $name (${_size(file)}).');
  });

  Future<void> _restoreBackup() => _run(() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final backup = ref.read(backupServiceProvider);
    final manifest = await backup.inspect(File(path));
    if (manifest == null) {
      _say('That zip has no manifest — it is not a Keller Twelve backup.');
      return;
    }
    if (!mounted) return;

    final ok = await _confirm(
      title: 'Replace everything on this phone?',
      body:
          'The backup holds ${manifest.summary}, taken '
          '${DateFormat('d MMMM yyyy').format(manifest.createdAt)}.\n\n'
          'Restoring wipes what is on the phone now and puts that back. '
          'There is no undo.',
      action: 'Restore',
      destructive: true,
    );
    if (!ok) return;

    await backup.restore(File(path));
    ref.read(programmeEditControllerProvider.notifier).refreshAfterRestore();
    _say('Restored ${manifest.summary}.');
  });

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppTheme.oxblood)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static String _size(File f) {
    final mb = f.lengthSync() / (1024 * 1024);
    return mb < 1
        ? '${(mb * 1024).toStringAsFixed(0)} KB'
        : '${mb.toStringAsFixed(1)} MB';
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colour = destructive ? AppTheme.oxblood : AppTheme.text;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colour),
              Gap.m,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium?.copyWith(color: colour)),
                    Gap.xs,
                    Text(
                      body,
                      style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The diff, before an import is applied.
class _ImportSheet extends StatelessWidget {
  const _ImportSheet({required this.preview});

  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final diff = preview.diff;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this would change', style: t.titleLarge),
            Gap.xs,
            Text(
              diff.summary,
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),

            if (preview.isRevisionConflict) ...[
              Gap.m,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warn.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppTheme.warn.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warn,
                      size: 20,
                    ),
                    Gap.s,
                    Expanded(
                      child: Text(
                        'That file is revision ${preview.incoming.revision}; '
                        'the phone is on ${diff.from.revision}. It is older '
                        'than what is here, so importing it would undo edits '
                        'you made since exporting.',
                        style: t.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (preview.errors.isNotEmpty) ...[
              Gap.m,
              ProblemStrip(problems: preview.errors),
            ],

            Gap.m,
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in diff.changes.take(60))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 16,
                            child: Text(
                              c.glyph,
                              style: t.bodyMedium?.copyWith(
                                color: switch (c.kind) {
                                  ChangeKind.added => AppTheme.good,
                                  ChangeKind.removed => AppTheme.oxblood,
                                  ChangeKind.modified => AppTheme.warn,
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${c.scope} ${c.id} — ${c.description}',
                              style: t.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            Gap.m,
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: preview.canApply
                          ? () => Navigator.pop(context, true)
                          : null,
                      child: Text(
                        preview.canApply ? 'Import' : 'Cannot import',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
