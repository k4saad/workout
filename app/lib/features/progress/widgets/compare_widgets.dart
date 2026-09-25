import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Two photos stacked with a draggable divider.
///
/// This is the comparison that actually reveals change. Side by side you
/// compare two pictures; with a wipe you compare the same pixels, and the
/// shoulders either moved or they did not.
class WipeCompare extends StatefulWidget {
  const WipeCompare({
    super.key,
    required this.before,
    required this.after,
    this.beforeLabel,
    this.afterLabel,
    this.initialPosition = 0.5,
  });

  final File before;
  final File after;
  final String? beforeLabel;
  final String? afterLabel;
  final double initialPosition;

  @override
  State<WipeCompare> createState() => _WipeCompareState();
}

class _WipeCompareState extends State<WipeCompare> {
  late double _pos = widget.initialPosition;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final x = (c.maxWidth * _pos).clamp(0.0, c.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => setState(() {
            _pos = ((_pos * c.maxWidth + d.delta.dx) / c.maxWidth).clamp(
              0.0,
              1.0,
            );
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(widget.after, fit: BoxFit.cover),
                ClipRect(
                  clipper: _LeftClipper(x),
                  child: Image.file(widget.before, fit: BoxFit.cover),
                ),
                Positioned(
                  left: x - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
                Positioned(
                  left: x - 22,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                if (widget.beforeLabel != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _Tag(text: widget.beforeLabel!),
                  ),
                if (widget.afterLabel != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _Tag(text: widget.afterLabel!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.x);
  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, x, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.x != x;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

/// Every photo of one pose, played in order: a time-lapse.
///
/// Sixteen weekly frames of the same pose is the single most motivating thing
/// this app will do — a mirror shows you today, this shows you the slope.
/// Each frame fades into the next, so the change reads as movement rather
/// than as a slideshow of different pictures.
class Flipbook extends StatefulWidget {
  const Flipbook({
    super.key,
    required this.frames,
    this.captions = const [],
    this.aspectRatio = 9 / 16,
    this.frameTime = const Duration(milliseconds: 1100),
  });

  final List<File> frames;
  final List<String> captions;

  /// Width over height of the photos.
  final double aspectRatio;

  /// How long each frame holds while playing.
  final Duration frameTime;

  @override
  State<Flipbook> createState() => _FlipbookState();
}

class _FlipbookState extends State<Flipbook> {
  int _index = 0;
  Timer? _player;

  @override
  void dispose() {
    _player?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_player != null) {
      _player!.cancel();
      setState(() => _player = null);
      return;
    }
    setState(() {
      _player = Timer.periodic(widget.frameTime, (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % widget.frames.length);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (widget.frames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No photos of this pose yet.',
          style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
        ),
      );
    }

    final caption = _index < widget.captions.length
        ? widget.captions[_index]
        : '';

    final fade = AppMotion.reduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 500);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: fade,
              // Both frames fill the box, so the old one fades out exactly
              // under the new one.
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: Image.file(
                widget.frames[_index],
                key: ValueKey(_index),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(caption, style: t.bodyMedium?.copyWith(color: AppTheme.textDim)),
        Row(
          children: [
            IconButton(
              iconSize: 30,
              onPressed: () => setState(
                () => _index = (_index - 1).clamp(0, widget.frames.length - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Slider(
                value: _index.toDouble(),
                min: 0,
                max: (widget.frames.length - 1).toDouble().clamp(0, 999),
                divisions: widget.frames.length > 1
                    ? widget.frames.length - 1
                    : null,
                label: '${_index + 1} / ${widget.frames.length}',
                onChanged: (v) => setState(() => _index = v.round()),
              ),
            ),
            IconButton(
              iconSize: 30,
              onPressed: () => setState(
                () => _index = (_index + 1).clamp(0, widget.frames.length - 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              iconSize: 30,
              tooltip: _player == null ? 'Play' : 'Pause',
              onPressed: widget.frames.length > 1 ? _togglePlay : null,
              icon: Icon(_player == null ? Icons.play_arrow : Icons.pause),
            ),
          ],
        ),
      ],
    );
  }
}

/// Two photos of the same pose, next to each other, captioned.
class SideBySide extends StatelessWidget {
  const SideBySide({
    super.key,
    required this.before,
    required this.after,
    required this.beforeCaption,
    required this.afterCaption,
    this.aspectRatio = 9 / 16,
  });

  final File before;
  final File after;
  final String beforeCaption;
  final String afterCaption;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Pane(
            file: before,
            caption: beforeCaption,
            aspectRatio: aspectRatio,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pane(
            file: after,
            caption: afterCaption,
            aspectRatio: aspectRatio,
          ),
        ),
      ],
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({
    required this.file,
    required this.caption,
    required this.aspectRatio,
  });

  final File file;
  final String caption;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }
}
