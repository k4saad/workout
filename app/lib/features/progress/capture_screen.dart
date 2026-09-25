import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/progress_providers.dart';
import '../../app/providers.dart';
import '../../app/settings_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/capture_camera.dart';
import '../../data/db/database.dart';
import '../../data/media_repository.dart';
import '../../data/photo_processing.dart';
import '../../data/preferences_service.dart';

/// One pass through every pose, lined up against last time.
///
/// The ghost is the whole feature: progress photos usually prove nothing
/// because the distance, angle and stance drift, so the previous photo of
/// the same pose is drawn over the live preview, in the same frame, and he
/// lines up against his past self.
///
/// Nothing is written until a photo is kept: opening the camera and backing
/// out leaves no empty shoot, and a retake replaces rather than adds.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.weekNo});

  final int? weekNo;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Stage { opening, framing, counting, processing, review, failed }

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  // Made in initState, not lazily: a lazy field first touched in dispose()
  // would reach for ref after it is gone.
  late final CaptureCamera _camera;
  late final CaptureCue _cue;

  _Stage _stage = _Stage.opening;
  Object? _error;
  String? _problem;

  MediaRepository? _media;
  List<PhotoPose> _poses = const [];
  int _index = 0;
  final _kept = <String>{};
  final _skipped = <String>{};
  PhotoShoot? _shoot;

  File? _ghost;
  bool _showGhost = true;
  double _ghostOpacity = 0.35;
  bool _showGrid = true;

  bool _front = true;
  int _timerSec = 10;
  int? _left;
  Timer? _timer;
  ProcessedPhoto? _pending;

  PhotoPose get _pose => _poses[_index];

  @override
  void initState() {
    super.initState();
    _camera = ref.read(captureCameraProvider)();
    _cue = ref.read(captureCueProvider)();
    unawaited(_boot());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_camera.dispose());
    unawaited(_cue.dispose());
    super.dispose();
  }

  Future<Preferences> _prefs() async {
    try {
      return await ref.read(preferencesProvider.future);
    } on Object {
      return const Preferences();
    }
  }

  Future<void> _boot() async {
    try {
      final media = await ref.read(mediaRepositoryProvider.future);
      await media.ensurePosesSeeded();
      final poses = await media.db.enabledPoses();
      if (poses.isEmpty) throw StateError('No poses to shoot.');
      final prefs = await _prefs();
      _media = media;
      _poses = poses;
      _front = prefs.captureFront;
      _timerSec = prefs.captureTimerSec;
      await _camera.open(front: _front);
      await _loadGhost();
      if (mounted) setState(() => _stage = _Stage.framing);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _stage = _Stage.failed;
        });
      }
    }
  }

  Future<void> _loadGhost() async {
    final ghost = await _media!.ghostFor(_pose.id);
    if (mounted) setState(() => _ghost = ghost);
  }

  Future<void> _savePrefs(Preferences Function(Preferences) change) async {
    try {
      final prefs = await ref.read(preferencesProvider.future);
      await ref.read(preferencesProvider.notifier).set(change(prefs));
    } on Object {
      // A preference that does not stick costs a tap next time.
    }
  }

  Future<void> _switchLens() async {
    setState(() {
      _stage = _Stage.opening;
      _front = !_front;
    });
    try {
      await _camera.open(front: _front);
      if (mounted) setState(() => _stage = _Stage.framing);
      await _savePrefs((p) => p.copyWith(captureFront: _front));
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _stage = _Stage.failed;
        });
      }
    }
  }

  void _setTimer(int seconds) {
    setState(() => _timerSec = seconds);
    unawaited(_savePrefs((p) => p.copyWith(captureTimerSec: seconds)));
  }

  void _startTimer() {
    setState(() {
      _problem = null;
      _stage = _Stage.counting;
      _left = _timerSec;
    });
    unawaited(_cue.tick(_timerSec));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final next = (_left ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        unawaited(_cue.shutter());
        unawaited(_take());
      } else {
        setState(() => _left = next);
        unawaited(_cue.tick(next));
      }
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    setState(() {
      _left = null;
      _stage = _Stage.framing;
    });
  }

  Future<void> _take() async {
    setState(() {
      _left = null;
      _stage = _Stage.processing;
    });
    try {
      final raw = await _camera.takePicture();
      final photo = await ref.read(photoProcessorProvider)(raw);
      if (!mounted) return;
      setState(() {
        _pending = photo;
        _stage = _Stage.review;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _problem = 'That one did not come out. Take it again.';
        _stage = _Stage.framing;
      });
    }
  }

  void _retake() => setState(() {
    _pending = null;
    _stage = _Stage.framing;
  });

  Future<void> _keep() async {
    final photo = _pending;
    final media = _media;
    if (photo == null || media == null) return;
    setState(() => _stage = _Stage.processing);
    try {
      // The shoot is made with its first kept photo, never before.
      final shoot = _shoot ??= await media.startShoot(
        ref.read(todayProvider),
        weekNo: widget.weekNo ?? ref.read(currentWeekProvider),
      );
      await media.savePhoto(
        shootId: shoot.id,
        poseId: _pose.id,
        bytes: photo.bytes,
        thumb: photo.thumb,
        width: photo.width,
        height: photo.height,
      );
      _kept.add(_pose.id);
      _pending = null;
      await _advance();
    } on Object {
      if (!mounted) return;
      setState(() {
        _problem = 'Could not save it. Try keeping it again.';
        _stage = _Stage.review;
      });
    }
  }

  Future<void> _skip() async {
    _skipped.add(_pose.id);
    await _advance();
  }

  /// On to the next pose not yet kept or skipped, or done.
  Future<void> _advance() async {
    for (var i = 1; i <= _poses.length; i++) {
      final next = (_index + i) % _poses.length;
      final id = _poses[next].id;
      if (_kept.contains(id) || _skipped.contains(id)) continue;
      setState(() {
        _index = next;
        _stage = _Stage.framing;
      });
      await _loadGhost();
      return;
    }
    _finish();
  }

  void _finish() {
    if (!mounted) return;
    final n = _kept.length;
    if (n > 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            n == _poses.length
                ? 'Shoot saved: all $n poses.'
                : 'Shoot saved: $n of ${_poses.length} poses.',
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<bool> _confirmLeave() async {
    if (_kept.isEmpty && _pending == null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the shoot?'),
        content: Text(
          [
            if (_kept.isNotEmpty)
              '${_kept.length} of ${_poses.length} poses are saved and stay '
                  'saved.',
            if (_pending != null) 'The photo on screen is not kept.',
          ].join(' '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep shooting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.failed) return _Failed(error: _error);
    if (_poses.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _timer?.cancel();
        if (await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        } else if (_stage == _Stage.counting) {
          _cancelTimer();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(_pose.name),
          actions: [
            IconButton(
              tooltip: _showGrid ? 'Hide grid' : 'Show grid',
              icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
              onPressed: () => setState(() => _showGrid = !_showGrid),
            ),
            if (_ghost != null)
              IconButton(
                tooltip: _showGhost ? 'Hide last time' : 'Show last time',
                icon: Icon(
                  _showGhost
                      ? Icons.layers_outlined
                      : Icons.layers_clear_outlined,
                ),
                onPressed: () => setState(() => _showGhost = !_showGhost),
              ),
            IconButton(
              tooltip: _front ? 'Use the back camera' : 'Use the front camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _stage == _Stage.framing || _stage == _Stage.opening
                  ? _switchLens
                  : null,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _PoseRow(
                poses: _poses,
                index: _index,
                kept: _kept,
                skipped: _skipped,
              ),
              Expanded(child: _frame()),
              _panel(context),
            ],
          ),
        ),
      ),
    );
  }

  /// The preview, the ghost and the review all in ONE box of the camera's
  /// shape, each filling it the same way — so what lines up on screen lines
  /// up in the photos. v2 drew the ghost over the whole screen while the
  /// preview kept its own shape, and they did not match.
  Widget _frame() {
    final reviewing = _stage == _Stage.review && _pending != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: _camera.isOpen ? _camera.portraitAspect : 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF050506)),
                if (reviewing)
                  Image.memory(
                    _pending!.bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                else if (_camera.isOpen && _stage != _Stage.opening)
                  _camera.preview(),
                if (_ghost != null && _showGhost)
                  IgnorePointer(
                    child: Opacity(
                      opacity: _ghostOpacity,
                      child: Image.file(_ghost!, fit: BoxFit.cover),
                    ),
                  ),
                if (_showGrid && !reviewing) const _RuleOfThirds(),
                if (_stage == _Stage.counting && _left != null)
                  Center(
                    child: Text(
                      '$_left',
                      style: AppTheme.numeric(140).copyWith(
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                if (_stage == _Stage.processing || _stage == _Stage.opening)
                  const Center(child: CircularProgressIndicator()),
                if (reviewing)
                  const Positioned(
                    left: 12,
                    top: 12,
                    child: _Tag('JUST TAKEN'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dim = t.bodyMedium!.copyWith(color: Colors.white70);
    Widget buttons(List<Widget> children) => Row(
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) Gap.s, c],
      ],
    );

    final body = switch (_stage) {
      _Stage.review => [
        Text('Keep this one?', style: t.titleMedium),
        Gap.xs,
        Text(
          _ghost == null
              ? 'The first of this pose. Next time lines up against it.'
              : 'Toggle last time (top right) to check the line-up.',
          style: dim,
          textAlign: TextAlign.center,
        ),
        Gap.m,
        buttons([
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.replay),
                label: const Text('Retake'),
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _keep,
                icon: const Icon(Icons.check),
                label: const Text('Keep'),
              ),
            ),
          ),
        ]),
      ],
      _Stage.counting => [
        Text('Step back and hold the pose.', style: t.titleMedium),
        Gap.xs,
        Text('It takes the picture at zero.', style: dim),
        Gap.m,
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _cancelTimer,
            child: const Text('Cancel'),
          ),
        ),
      ],
      _Stage.processing || _Stage.opening => [
        Text(
          _stage == _Stage.opening ? 'Opening the camera…' : 'Saving…',
          style: dim,
        ),
        const SizedBox(height: 80),
      ],
      _ => [
        if (_pose.guidance != null)
          Text(_pose.guidance!, textAlign: TextAlign.center, style: dim),
        if (_ghost != null && _showGhost)
          Row(
            children: [
              const Icon(Icons.opacity, size: 18, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: _ghostOpacity,
                  min: 0.1,
                  max: 0.7,
                  onChanged: (v) => setState(() => _ghostOpacity = v),
                ),
              ),
              Text('${(_ghostOpacity * 100).round()}%', style: dim),
            ],
          ),
        Gap.s,
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Timer', style: dim),
            for (final s in Preferences.captureTimers)
              ChoiceChip(
                label: Text('$s s'),
                selected: _timerSec == s,
                onSelected: (_) => _setTimer(s),
              ),
          ],
        ),
        Gap.m,
        buttons([
          SizedBox(
            height: 56,
            child: OutlinedButton(onPressed: _skip, child: const Text('Skip')),
          ),
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _camera.isOpen ? _startTimer : null,
                icon: const Icon(Icons.timer_outlined),
                label: Text('Start the $_timerSec s timer'),
              ),
            ),
          ),
        ]),
      ],
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_problem != null) ...[
            ToneBanner(tone: Tone.warn, title: _problem!),
            Gap.s,
          ],
          ...body,
        ],
      ),
    );
  }
}

/// Which pose, of how many, and what became of the others.
class _PoseRow extends StatelessWidget {
  const _PoseRow({
    required this.poses,
    required this.index,
    required this.kept,
    required this.skipped,
  });

  final List<PhotoPose> poses;
  final int index;
  final Set<String> kept;
  final Set<String> skipped;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          for (final (i, p) in poses.indexed)
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == index
                          ? AppTheme.crimson
                          : kept.contains(p.id)
                          ? AppTheme.good
                          : AppTheme.surfaceHigher,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kept.contains(p.id)
                        ? '✓ ${i + 1}'
                        : skipped.contains(p.id)
                        ? '– ${i + 1}'
                        : '${i + 1}',
                    style: t.labelSmall!.copyWith(
                      color: i == index ? AppTheme.text : AppTheme.textDim,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: AppTheme.overline.copyWith(color: Colors.white, fontSize: 11),
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Column(
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 44,
                color: AppTheme.warn,
              ),
              Gap.m,
              Text('The camera did not open', style: t.titleLarge),
              Gap.s,
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
              Gap.l,
              Text(
                'Check that the app may use the camera (Android Settings → '
                'Apps → Keller Twelve → Permissions), then come back. Do not '
                'use the phone’s camera app instead: those photos land in the '
                'gallery, and from there in Google Photos.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleOfThirds extends StatelessWidget {
  const _RuleOfThirds();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
