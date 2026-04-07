import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/khair_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  KHAIR LOADING SYSTEM — Premium, Modern, 60fps
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────
//  1. SHIMMER EFFECT (Core Building Block)
// ─────────────────────────────────────────────

/// High-performance shimmer loading effect with gradient sweep.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: isDark
                  ? [
                      const Color(0xFF1A1F2E),
                      const Color(0xFF252B3B),
                      const Color(0xFF1A1F2E),
                    ]
                  : [
                      const Color(0xFFE8E8E8),
                      const Color(0xFFF5F5F5),
                      const Color(0xFFE8E8E8),
                    ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  2. SKELETON PRIMITIVES
// ─────────────────────────────────────────────

/// Skeleton box for loading placeholders.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Circular skeleton (for avatars).
class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE0E0E0),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  3. FULL-SCREEN BRANDED LOADING
// ─────────────────────────────────────────────

/// Premium full-screen loading with animated gradient, logo pulse,
/// and rotating messages. Used for app startup and deep links.
class KhairFullScreenLoading extends StatefulWidget {
  final List<String>? messages;

  const KhairFullScreenLoading({super.key, this.messages});

  @override
  State<KhairFullScreenLoading> createState() => _KhairFullScreenLoadingState();
}

class _KhairFullScreenLoadingState extends State<KhairFullScreenLoading>
    with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _messageController;

  int _messageIndex = 0;

  static const _defaultMessages = [
    'Connecting you to الخير',
    'Discovering meaningful events',
    'Building your community',
    'Finding knowledge near you',
  ];

  List<String> get _messages => widget.messages ?? _defaultMessages;

  @override
  void initState() {
    super.initState();

    // Gradient animation
    _gradientController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Logo pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Initial fade-in
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // Message rotation
    _messageController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _startMessageRotation();
  }

  void _startMessageRotation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _messageController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
        _messageController.forward();
      });
      _startMessageRotation();
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, _) {
        final angle = _gradientController.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(math.cos(angle), math.sin(angle)),
              end: Alignment(-math.cos(angle), -math.sin(angle)),
              colors: const [
                Color(0xFF0A1628), // Deep navy
                Color(0xFF0D2818), // Deep forest
                Color(0xFF0F1D2E), // Midnight blue
                Color(0xFF0A1A12), // Dark green
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeController,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Subtle geometric pattern behind logo
                  _buildGeometricPattern(),
                  const SizedBox(height: 40),
                  // Animated logo
                  _buildPulsingLogo(),
                  const SizedBox(height: 48),
                  // Rotating message
                  _buildRotatingMessage(),
                  const SizedBox(height: 32),
                  // Subtle loading indicator
                  _buildLoadingDots(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeometricPattern() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, _) {
        return Opacity(
          opacity: 0.04,
          child: Transform.rotate(
            angle: _gradientController.value * 0.5,
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _IslamicPatternPainter(
                  rotation: _gradientController.value * math.pi * 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulsingLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        final opacity = 0.7 + (_pulseController.value * 0.3);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    KhairColors.primary,
                    KhairColors.primary.withValues(alpha: 0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: KhairColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24 + (_pulseController.value * 12),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'خ',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRotatingMessage() {
    return FadeTransition(
      opacity: _messageController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _messageController,
          curve: Curves.easeOut,
        )),
        child: Text(
          _messages[_messageIndex],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return SizedBox(
      width: 40,
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final delay = i * 0.2;
              final value = ((_pulseController.value + delay) % 1.0);
              final opacity = 0.3 + (math.sin(value * math.pi) * 0.7);
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KhairColors.primary.withValues(alpha: opacity),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Subtle Islamic-inspired geometric pattern painter.
class _IslamicPatternPainter extends CustomPainter {
  final double rotation;
  _IslamicPatternPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw 8-pointed star pattern
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + rotation;
      final start = Offset(
        center.dx + radius * 0.3 * math.cos(angle),
        center.dy + radius * 0.3 * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }

    // Concentric circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, paint);
    }
  }

  @override
  bool shouldRepaint(_IslamicPatternPainter old) => old.rotation != rotation;
}

// ─────────────────────────────────────────────
//  4. SMART LOADING WRAPPER
// ─────────────────────────────────────────────

/// Smart loading that avoids flicker and shows progressive states.
/// - <500ms: shows nothing
/// - 500ms–2s: shows skeleton
/// - 2s–5s: shows skeleton + message
/// - >5s: shows retry button
class SmartLoadingWrapper extends StatefulWidget {
  final bool isLoading;
  final Widget skeleton;
  final Widget child;
  final VoidCallback? onRetry;
  final String? longLoadMessage;

  const SmartLoadingWrapper({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.child,
    this.onRetry,
    this.longLoadMessage,
  });

  @override
  State<SmartLoadingWrapper> createState() => _SmartLoadingWrapperState();
}

class _SmartLoadingWrapperState extends State<SmartLoadingWrapper> {
  bool _showSkeleton = false;
  bool _showMessage = false;
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _startLoadTimer();
  }

  @override
  void didUpdateWidget(SmartLoadingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _startLoadTimer();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _resetTimers();
    }
  }

  void _startLoadTimer() {
    _resetTimers();

    // Show skeleton after 500ms
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && widget.isLoading) setState(() => _showSkeleton = true);
    });

    // Show message after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && widget.isLoading) setState(() => _showMessage = true);
    });

    // Show retry after 5s
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && widget.isLoading) setState(() => _showRetry = true);
    });
  }

  void _resetTimers() {
    _showSkeleton = false;
    _showMessage = false;
    _showRetry = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: widget.child,
      );
    }

    if (!_showSkeleton) {
      // Under 500ms — show nothing to avoid flicker
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          Expanded(child: widget.skeleton),
          if (_showMessage)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: 1.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.longLoadMessage ?? 'Still loading… optimizing your experience',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (_showRetry && widget.onRetry != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: 1.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton.icon(
                  onPressed: () {
                    _resetTimers();
                    widget.onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: KhairColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  5. SKELETON PRESETS
// ─────────────────────────────────────────────

/// Event card skeleton for loading state.
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 160, borderRadius: 12),
          SizedBox(height: 14),
          SkeletonBox(width: 220, height: 18),
          SizedBox(height: 8),
          SkeletonBox(width: 160, height: 14),
          SizedBox(height: 14),
          Row(children: [
            SkeletonBox(width: 110, height: 14),
            SizedBox(width: 16),
            SkeletonBox(width: 130, height: 14),
          ]),
        ],
      ),
    );
  }
}

/// Events list skeleton.
class EventsListSkeleton extends StatelessWidget {
  final int itemCount;
  const EventsListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) => const EventCardSkeleton(),
      ),
    );
  }
}

/// Event details page skeleton — shows when deep links load.
class EventDetailsSkeleton extends StatelessWidget {
  const EventDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            SkeletonBox(height: 280, borderRadius: 0),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  Row(children: [
                    SkeletonBox(width: 70, height: 28, borderRadius: 14),
                    const SizedBox(width: 8),
                    SkeletonBox(width: 90, height: 28, borderRadius: 14),
                  ]),
                  const SizedBox(height: 16),
                  // Title
                  const SkeletonBox(width: double.infinity, height: 24),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 200, height: 24),
                  const SizedBox(height: 20),
                  // Info cards
                  Row(children: [
                    Expanded(child: SkeletonBox(height: 90, borderRadius: 14)),
                    const SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 90, borderRadius: 14)),
                  ]),
                  const SizedBox(height: 20),
                  // Description block
                  _section(isDark),
                  const SizedBox(height: 16),
                  // Location block
                  _section(isDark),
                  const SizedBox(height: 16),
                  // Attendees block
                  _section(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SkeletonBox(width: 22, height: 22, borderRadius: 6),
            const SizedBox(width: 10),
            SkeletonBox(width: 120, height: 17),
          ]),
          const SizedBox(height: 16),
          const SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          const SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          const SkeletonBox(width: 200, height: 14),
        ],
      ),
    );
  }
}

/// Sheikh profile skeleton — shows when deep link loads.
class SheikhProfileSkeleton extends StatelessWidget {
  const SheikhProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header gradient
            Container(
              height: 220,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1117), Color(0xFF151A26)],
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonCircle(size: 100),
                  SizedBox(height: 16),
                  SkeletonBox(width: 180, height: 22),
                  SizedBox(height: 8),
                  SkeletonBox(width: 130, height: 16),
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat cards
                  Row(children: [
                    Expanded(child: SkeletonBox(height: 70, borderRadius: 14)),
                    const SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 70, borderRadius: 14)),
                    const SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 70, borderRadius: 14)),
                  ]),
                  const SizedBox(height: 24),
                  // Bio section
                  const SkeletonBox(width: 80, height: 18),
                  const SizedBox(height: 12),
                  const SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 200, height: 14),
                  const SizedBox(height: 24),
                  // Reviews section
                  const SkeletonBox(width: 100, height: 18),
                  const SizedBox(height: 12),
                  SkeletonBox(width: double.infinity, height: 100, borderRadius: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat message skeleton.
class ChatMessageSkeleton extends StatelessWidget {
  final bool isMe;
  const ChatMessageSkeleton({super.key, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            const SkeletonCircle(size: 32),
            const SizedBox(width: 8),
          ],
          SkeletonBox(
            width: 180 + (isMe ? 20 : 0),
            height: 42,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }
}

/// Chat list skeleton.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const ChatMessageSkeleton(),
            const ChatMessageSkeleton(isMe: true),
            const ChatMessageSkeleton(),
            const ChatMessageSkeleton(),
            const ChatMessageSkeleton(isMe: true),
            const ChatMessageSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// Organizer card skeleton.
class OrganizerCardSkeleton extends StatelessWidget {
  const OrganizerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          SkeletonCircle(size: 48),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 16),
                SizedBox(height: 6),
                SkeletonBox(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  6. BUTTON LOADING STATE
// ─────────────────────────────────────────────

/// Premium loading button that replaces text with spinner.
class KhairLoadingButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final double height;

  const KhairLoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? KhairColors.primary,
          foregroundColor: foregroundColor ?? Colors.white,
          disabledBackgroundColor:
              (backgroundColor ?? KhairColors.primary).withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: foregroundColor ?? Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}


