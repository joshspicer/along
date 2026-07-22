import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/platform/haptics.dart';
import '../../../core/widgets/along_mark.dart';
import '../domain/focus_session.dart';

class AuthoritativeTimer extends StatefulWidget {
  const AuthoritativeTimer({
    required this.session,
    required this.authoritativeNow,
    super.key,
    this.onElapsed,
    this.caption,
    this.compact = false,
  });

  final FocusSession session;
  final DateTime Function() authoritativeNow;
  final VoidCallback? onElapsed;
  final String? caption;
  final bool compact;

  @override
  State<AuthoritativeTimer> createState() => _AuthoritativeTimerState();
}

class _AuthoritativeTimerState extends State<AuthoritativeTimer> {
  Timer? _ticker;
  bool _reportedElapsed = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant AuthoritativeTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.state != widget.session.state) {
      _reportedElapsed = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.session.remainingAt(widget.authoritativeNow());
    final seconds = remaining.inSeconds.clamp(
      0,
      widget.session.durationSeconds,
    );
    final minutesPart = seconds ~/ 60;
    final secondsPart = seconds % 60;
    final label =
        '${minutesPart.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}';
    final progress = seconds / widget.session.durationSeconds;
    final size = widget.compact ? 250.0 : 292.0;
    final caption =
        widget.caption ??
        (widget.session.state == SessionState.paused
            ? 'Paused'
            : widget.session.state == SessionState.together
            ? 'Focus together'
            : 'Focus');
    return Semantics(
      label: '$label remaining. $caption',
      liveRegion: true,
      value: label,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _TimerPainter(
              progress: progress,
              track: context.colorScheme.primaryContainer,
              color: context.colorScheme.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: context.textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (!_reportedElapsed &&
        widget.session.state != SessionState.paused &&
        widget.session.remainingAt(widget.authoritativeNow()) ==
            Duration.zero) {
      _reportedElapsed = true;
      unawaited(AlongHaptics.success());
      widget.onElapsed?.call();
    }
  }
}

class _TimerPainter extends CustomPainter {
  const _TimerPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = track;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.color != color;
}
