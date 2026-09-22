import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../../app/progress_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/database.dart';

/// Shoots one pass through every enabled pose.
///
/// The ghost overlay is the whole feature. Progress photos usually prove
/// nothing because the distance, angle and stance all drift — so the previous
/// photo of the same pose is drawn semi-transparent over the live viewfinder
/// and you line yourself up against your past self.
///
/// `image_picker` cannot do this: it hands off to the system camera app and
/// there is nowhere to draw. That is the entire reason for the `camera`
/// dependency.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.weekNo});

  final int? weekNo;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _camera;
  Object? _error;

  PhotoShoot? _shoot;
  List<PhotoPose> _poses = const [];
  int _poseIndex = 0;

  File? _ghost;
  double _ghostOpacity = 0.30;
  bool _showGhost = true;
  bool _showGrid = true;

  int? _countdown;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final media = await ref.read(mediaRepositoryProvider.future);
      await media.ensurePosesSeeded();
      final poses = await media.db.enabledPoses();

      final shoot = await media.startShoot(
        ref.read(todayProvider),
        weekNo: widget.weekNo,
      );

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera on this device.');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _camera = controller;
        _poses = poses;
        _shoot = shoot;
      });
      await _loadGhost();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadGhost() async {
    if (_poses.isEmpty) return;
    final media = await ref.read(mediaRepositoryProvider.future);
    final ghost = await media.ghostFor(_poses[_poseIndex].id);
    if (mounted) setState(() => _ghost = ghost);
  }

  void _startCountdown() {
    if (_busy) return;
    // You are propping the phone on the bench, not holding it.
    setState(() => _countdown = 3);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final next = (_countdown ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _countdown = null);
        unawaited(_capture());
      } else {
        setState(() => _countdown = next);
      }
    });
  }

  Future<void> _capture() async {
    final camera = _camera;
    final shoot = _shoot;
    if (camera == null || shoot == null || _busy) return;
    setState(() => _busy = true);

    try {
      final shot = await camera.takePicture();
      final raw = await File(shot.path).readAsBytes();

      // Resize to a 1920 px long edge at q85: roughly 400-600 KB, which keeps
      // a year of weekly shoots inside the storage budget.
      final decoded = img.decodeImage(raw);
      final Uint8List resized = decoded == null
          ? raw
          : img.encodeJpg(
              decoded.width >= decoded.height
                  ? img.copyResize(decoded, width: 1920)
                  : img.copyResize(decoded, height: 1920),
              quality: 85,
            );

      final media = await ref.read(mediaRepositoryProvider.future);
      await media.savePhoto(
        shootId: shoot.id,
        poseId: _poses[_poseIndex].id,
        bytes: resized,
        width: decoded?.width ?? 0,
        height: decoded?.height ?? 0,
      );

      // The temp file the plugin wrote is NOT app-private; remove it.
      final tmp = File(shot.path);
      if (tmp.existsSync()) await tmp.delete();

      ref.invalidate(shootsProvider);

      if (!mounted) return;
      if (_poseIndex + 1 < _poses.length) {
        setState(() {
          _poseIndex++;
          _busy = false;
        });
        await _loadGhost();
      } else {
        if (mounted) context.go('/progress');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 44,
                color: AppTheme.warn,
              ),
              const SizedBox(height: 14),
              Text('Camera unavailable', style: t.titleLarge),
              const SizedBox(height: 8),
              Text(
                '$_error',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
              const SizedBox(height: 20),
              Text(
                'You can still shoot with the normal camera app and import '
                'later — but the ghost overlay is what keeps the angles '
                'consistent, so it is worth sorting out.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
        ),
      );
    }

    final camera = _camera;
    if (camera == null || _poses.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pose = _poses[_poseIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_poseIndex + 1} of ${_poses.length}'),
        actions: [
          IconButton(
            tooltip: _showGrid ? 'Hide grid' : 'Show grid',
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          if (_ghost != null)
            IconButton(
              tooltip: _showGhost ? 'Hide ghost' : 'Show ghost',
              icon: Icon(_showGhost ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showGhost = !_showGhost),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(camera),

                // The ghost: your past self, to line up against.
                if (_ghost != null && _showGhost)
                  Opacity(
                    opacity: _ghostOpacity,
                    child: Image.file(_ghost!, fit: BoxFit.cover),
                  ),

                if (_showGrid) const _RuleOfThirds(),

                if (_countdown != null)
                  Center(
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                Text(
                  pose.name.toUpperCase(),
                  style: t.labelLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
                if (pose.guidance != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    pose.guidance!,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
                if (_ghost != null && _showGhost) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.opacity,
                        size: 18,
                        color: Colors.white70,
                      ),
                      Expanded(
                        child: Slider(
                          value: _ghostOpacity,
                          min: 0.05,
                          max: 0.75,
                          onChanged: (v) => setState(() => _ghostOpacity = v),
                        ),
                      ),
                      Text(
                        '${(_ghostOpacity * 100).round()}%',
                        style: t.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _startCountdown,
                    icon: const Icon(Icons.timer_3_select),
                    label: Text(_busy ? 'Saving…' : 'Shoot (3s timer)'),
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

class _RuleOfThirds extends StatelessWidget {
  const _RuleOfThirds();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
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
