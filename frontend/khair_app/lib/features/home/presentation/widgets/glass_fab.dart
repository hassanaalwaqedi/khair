import 'dart:ui';
import 'package:flutter/material.dart';

/// Glassmorphism floating action button with slow pulse glow.
class GlassFab extends StatefulWidget {
  final VoidCallback? onPressed;
  const GlassFab({super.key, this.onPressed});

  @override
  State<GlassFab> createState() => _GlassFabState();
}

class _GlassFabState extends State<GlassFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = 0.12 + _pulseCtrl.value * 0.15;
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC8A951).withValues(alpha: glow),
                blurRadius: 20 + _pulseCtrl.value * 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xFFC8A951).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFFC8A951),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
