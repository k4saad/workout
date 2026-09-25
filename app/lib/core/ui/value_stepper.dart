import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'surfaces.dart';

/// A number set with the thumb: a fine step and a coarse one either side,
/// and a held button keeps stepping. Never a keyboard — a weigh-in happens
/// with wet hands and a tape measure with one.
class ValueStepper extends StatefulWidget {
  const ValueStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.step,
    this.bigStep,
    this.min = 0,
    this.max = 999,
    this.decimals = 1,
    this.unit,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double? bigStep;
  final double min;
  final double max;
  final int decimals;
  final String? unit;

  @override
  State<ValueStepper> createState() => _ValueStepperState();
}

class _ValueStepperState extends State<ValueStepper> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  late double _value = widget.value;

  @override
  void didUpdateWidget(ValueStepper old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  /// Rounded to the shown decimals every time: ten taps of 0.1 is 1.0, not
  /// 0.9999999999999999.
  void _bump(double by) {
    final next = double.parse(
      (_value + by)
          .clamp(widget.min, widget.max)
          .toStringAsFixed(widget.decimals),
    );
    if (next == _value) return;
    HapticFeedback.selectionClick();
    setState(() => _value = next);
    widget.onChanged(next);
  }

  void _hold(double by) {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) => _bump(by),
    );
  }

  void _release() {
    _repeat?.cancel();
    _repeat = null;
  }

  String _label(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : '$s';

  Widget _button(IconData icon, double by, {bool big = false}) {
    final label = '${by > 0 ? 'Up' : 'Down'} ${_label(by.abs())}';
    return Tooltip(
      message: label,
      child: GestureDetector(
        onLongPressStart: (_) => _hold(by),
        onLongPressEnd: (_) => _release(),
        onLongPressCancel: _release,
        child: SizedBox(
          width: big ? 56 : 64,
          height: 64,
          child: Material(
            color: big ? AppTheme.surfaceHigh : AppTheme.surfaceHigher,
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.m),
              onTap: () => _bump(by),
              child: Center(
                child: big
                    ? Text(
                        '${by > 0 ? '+' : '−'}${_label(by.abs())}',
                        style: AppTheme.numeric(18, color: AppTheme.textDim),
                      )
                    : Icon(icon, size: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final big = widget.bigStep;
    return Row(
      children: [
        if (big != null) ...[_button(Icons.remove, -big, big: true), Gap.s],
        _button(Icons.remove, -widget.step),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _value.toStringAsFixed(widget.decimals),
                  style: AppTheme.numeric(46),
                ),
                if (widget.unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.unit!,
                    style: t.titleMedium!.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ],
            ),
          ),
        ),
        _button(Icons.add, widget.step),
        if (big != null) ...[Gap.s, _button(Icons.add, big, big: true)],
      ],
    );
  }
}

/// A sheet with a [ValueStepper] and a Save button. Returns the value, or
/// null when closed without saving.
Future<double?> showStepperSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required double initial,
  required double step,
  double? bigStep,
  double min = 0,
  double max = 999,
  int decimals = 1,
  String? unit,
  String saveLabel = 'Save',
  Widget? footer,
}) {
  var value = initial;
  return showAppSheet<double>(
    context,
    builder: (context) {
      final t = Theme.of(context).textTheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headlineSmall),
          if (subtitle != null) ...[
            Gap.xs,
            Text(
              subtitle,
              style: t.bodyMedium!.copyWith(color: AppTheme.textDim),
            ),
          ],
          Gap.l,
          ValueStepper(
            value: initial,
            onChanged: (v) => value = v,
            step: step,
            bigStep: bigStep,
            min: min,
            max: max,
            decimals: decimals,
            unit: unit,
          ),
          Gap.l,
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: Text(saveLabel),
            ),
          ),
          if (footer != null) ...[Gap.m, footer],
        ],
      );
    },
  );
}
