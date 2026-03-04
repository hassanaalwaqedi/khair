import 'dart:math';
import 'package:flutter/material.dart';

/// Lightweight geometric Islamic pattern painted via CustomPainter.
/// Draws an interlocking star-polygon grid at very low opacity for
/// subtle background decoration. No external assets required.
class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double cellSize;

  IslamicPatternPainter({
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 0.06,
    this.cellSize = 48,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * cellSize;
        final cy = row * cellSize;
        _drawEightPointStar(canvas, Offset(cx, cy), cellSize * 0.4, paint);
      }
    }
  }

  void _drawEightPointStar(Canvas canvas, Offset center, double r, Paint paint) {
    // Draw an 8-pointed star using two overlapping squares rotated 45°
    final path1 = _rotatedSquare(center, r, 0);
    final path2 = _rotatedSquare(center, r, pi / 4);
    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);

    // Inner connecting lines for geometric depth
    final innerR = r * 0.45;
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final outerX = center.dx + r * cos(angle);
      final outerY = center.dy + r * sin(angle);
      final innerX = center.dx + innerR * cos(angle + pi / 8);
      final innerY = center.dy + innerR * sin(angle + pi / 8);
      canvas.drawLine(
        Offset(outerX, outerY),
        Offset(innerX, innerY),
        paint,
      );
    }
  }

  Path _rotatedSquare(Offset center, double r, double baseAngle) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = baseAngle + i * pi / 2;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter old) =>
      old.color != color || old.opacity != opacity || old.cellSize != cellSize;
}

/// Convenience widget that wraps the painter in a sized container.
class IslamicPatternBackground extends StatelessWidget {
  final Color color;
  final double opacity;
  final double cellSize;

  const IslamicPatternBackground({
    super.key,
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 0.06,
    this.cellSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: IslamicPatternPainter(
          color: color,
          opacity: opacity,
          cellSize: cellSize,
        ),
      ),
    );
  }
}
