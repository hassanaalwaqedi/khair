import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Circular progress indicator showing profile completion %
class CompletionScoreWidget extends StatelessWidget {
  final int score;
  final List<Map<String, dynamic>> suggestions;

  const CompletionScoreWidget({
    super.key,
    required this.score,
    this.suggestions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(100, 100),
                painter: _CircleProgressPainter(
                  progress: score / 100,
                  color: _getColor(score),
                  backgroundColor: Colors.grey.withOpacity(0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getColor(score),
                    ),
                  ),
                  Text(
                    'Complete',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Improve your profile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          ...suggestions.take(3).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      _getIcon(s['type'] as String? ?? ''),
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s['message'] as String? ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Color _getColor(int score) {
    if (score >= 80) return Colors.green[700]!;
    if (score >= 60) return Colors.green;
    if (score >= 40) return Colors.amber[700]!;
    if (score >= 20) return Colors.orange;
    return Colors.red;
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'missing':
        return Icons.add_circle_outline;
      case 'improvement':
        return Icons.lightbulb_outline;
      case 'tip':
        return Icons.tips_and_updates_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter old) =>
      old.progress != progress || old.color != color;
}
