import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps the real controls interactive through the highlighted opening.
class CoachMark extends StatefulWidget {
  const CoachMark({
    required this.child,
    required this.target,
    this.additionalTargets = const [],
    required this.title,
    this.description = '',
    required this.current,
    required this.total,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  final Widget child;
  final GlobalKey target;
  final List<GlobalKey> additionalTargets;
  final String title;
  final String description;
  final int current;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<CoachMark> createState() => _CoachMarkState();
}

class _CoachMarkState extends State<CoachMark> {
  final _stackKey = GlobalKey();
  final _bubbleKey = GlobalKey();
  Rect? _rect;
  List<Rect> _highlights = [];
  double _bubbleHeight = 166;

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stack = _stackKey.currentContext?.findRenderObject();
      if (stack is! RenderBox) return;
      final viewport = Offset.zero & stack.size;
      final highlights = <Rect>[];
      for (final key in [widget.target, ...widget.additionalTargets]) {
        final target = key.currentContext?.findRenderObject();
        if (target is! RenderBox || !target.attached || !target.hasSize)
          continue;
        final bounds =
            (target.localToGlobal(Offset.zero, ancestor: stack) & target.size)
                .inflate(4);
        if (bounds.overlaps(viewport))
          highlights.add(bounds.intersect(viewport));
      }
      final rect = highlights.isEmpty
          ? null
          : highlights.reduce((a, b) => a.expandToInclude(b));
      final bubble = _bubbleKey.currentContext?.findRenderObject();
      final height = bubble is RenderBox ? bubble.size.height : _bubbleHeight;
      if (rect != _rect ||
          height != _bubbleHeight ||
          !_sameRects(highlights, _highlights)) {
        setState(() {
          _rect = rect;
          _highlights = highlights;
          _bubbleHeight = height;
        });
      }
      // Async data can insert a target without rebuilding this overlay.
      if (rect == null) _measure();
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final scheme = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _measure();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rect = _rect;
          final bubbleHeight = _bubbleHeight;
          final available = constraints.maxHeight;
          final below = rect == null || available - rect.bottom >= rect.top;
          final desired = rect == null
              ? 12.0
              : below
              ? rect.bottom + 14
              : rect.top - bubbleHeight - 14;
          final top = desired
              .clamp(8.0, math.max(8.0, available - bubbleHeight - 8))
              .toDouble();
          return Stack(
            key: _stackKey,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SpotlightPainter(_highlights, scheme.primary),
                  ),
                ),
              ),
              if (rect != null && rect.height > 0)
                Positioned(
                  left:
                      rect.center.dx.clamp(
                        30.0,
                        math.max(30.0, constraints.maxWidth - 30),
                      ) -
                      10,
                  top: below ? top - 10 : top + bubbleHeight - 1,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(20, 11),
                      painter: _TailPainter(scheme.primaryContainer, below),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                top: top,
                child: Material(
                  key: _bubbleKey,
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                        if (widget.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${widget.current} / ${widget.total}',
                              key: const ValueKey('coach-progress'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: widget.onSkip,
                              child: const Text('건너뛰기'),
                            ),
                            FilledButton(
                              onPressed: widget.onNext,
                              child: const Text('다음'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.rects, this.color);
  final List<Rect> rects;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    for (final rect in rects) {
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    }
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .68));
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      !_sameRects(rects, oldDelegate.rects) || color != oldDelegate.color;
}

bool _sameRects(List<Rect> a, List<Rect> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color, this.below);
  final Color color;
  final bool below;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, below ? size.height : 0)
      ..lineTo(size.width / 2, below ? 0 : size.height)
      ..lineTo(size.width, below ? size.height : 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) =>
      color != oldDelegate.color || below != oldDelegate.below;
}
