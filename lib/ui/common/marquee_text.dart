import 'package:flutter/material.dart';

/// A single line of text that scrolls sideways when it is too long to fit, the
/// way iTunes scrolls a long track name: a beat to read the start, a slow pass
/// across, a beat at the far end, then back again.
///
/// Text that already fits is left completely alone — no clip, no animation, no
/// repainting. Long titles take *longer* to cross rather than scrolling faster,
/// so the reading speed stays the same however long the title is.
///
/// "Reduce motion" falls back to an ellipsis. A bedtime screen that a child is
/// settling in front of should stop moving when the OS says so.
class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 28,
    this.pause = const Duration(milliseconds: 1600),
  });

  final String text;
  final TextStyle? style;

  /// Scroll speed, in logical pixels per second.
  final double velocity;

  /// How long to hold still at each end before turning around.
  final Duration pause;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// How far the text runs past the space available, in pixels. Zero means it
  /// fits and nothing animates.
  double _overflow = 0;

  /// Share of one there-and-back cycle spent holding still at a single end.
  double _pauseFraction = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Re-time the cycle when the text, its style, or the room for it changes.
  void _retime(double overflow) {
    if (overflow == _overflow) return;
    _overflow = overflow;
    final travelMs = (overflow / widget.velocity * 1000).round();
    final pauseMs = widget.pause.inMilliseconds;
    final totalMs = 2 * (travelMs + pauseMs);
    _pauseFraction = totalMs == 0 ? 0 : pauseMs / totalMs;
    // This runs from inside layout, so the controller is only touched once the
    // frame has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (overflow <= 0) {
        _controller
          ..stop()
          ..value = 0;
        return;
      }
      _controller
        ..duration = Duration(milliseconds: totalMs)
        ..value = 0
        ..repeat();
    });
  }

  /// Where the line sits at cycle position [t], as a leftward pixel offset.
  ///
  /// The cycle is: hold at the start, ease across, hold at the end, ease back.
  /// Easing at both turns keeps it from snapping.
  double _offsetAt(double t) {
    final travel = 0.5 - _pauseFraction;
    if (travel <= 0) return 0;
    if (t < _pauseFraction) return 0;
    if (t < 0.5) {
      final progress = (t - _pauseFraction) / travel;
      return -_overflow * Curves.easeInOut.transform(progress);
    }
    if (t < 0.5 + _pauseFraction) return -_overflow;
    final progress = (t - 0.5 - _pauseFraction) / travel;
    return -_overflow * (1 - Curves.easeInOut.transform(progress));
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        widget.text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final overflow = (painter.width - constraints.maxWidth).clamp(
          0.0,
          double.infinity,
        );
        painter.dispose();
        _retime(overflow);

        // `softWrap: false` with visible overflow lets the line paint past its
        // box at full natural width while the box itself stays the width we
        // were given — which is what there is to clip and slide.
        final line = Text(
          widget.text,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        );
        if (overflow == 0) return line;

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(_offsetAt(_controller.value), 0),
              child: child,
            ),
            child: line,
          ),
        );
      },
    );
  }
}
