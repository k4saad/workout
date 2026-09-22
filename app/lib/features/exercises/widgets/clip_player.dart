import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';

/// One filmed set, with a minimal control bar.
///
/// Deliberately not `chewie`: play, scrub and delete is the whole feature
/// here, and that is less code to write than a control package is to
/// configure — one fewer dependency in an app that already holds a year of
/// training data and a gallery of private photos.
class ClipTile extends StatefulWidget {
  const ClipTile({
    super.key,
    required this.file,
    required this.caption,
    required this.onDelete,
  });

  final File file;
  final String caption;
  final VoidCallback onDelete;

  @override
  State<ClipTile> createState() => _ClipTileState();
}

class _ClipTileState extends State<ClipTile> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.file(widget.file);
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _controller;

    return Card(
      child: Column(
        children: [
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'This clip will not play. The file may have been removed '
                'outside the app.',
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            )
          else if (c == null)
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GestureDetector(
              onTap: _toggle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                  if (!c.value.isPlaying)
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          if (c != null)
            VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppTheme.oxblood,
                bufferedColor: AppTheme.outline,
                backgroundColor: AppTheme.surfaceHigh,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.caption,
                    style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete clip',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete this clip?'),
        content: const Text(
          'The video file is removed from the phone permanently.',
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
    if (ok == true) widget.onDelete();
  }
}
