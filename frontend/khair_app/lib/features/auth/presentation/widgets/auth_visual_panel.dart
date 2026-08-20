import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';

class AuthVisualPanel extends StatelessWidget {
  const AuthVisualPanel({
    super.key,
    this.heading = 'Welcome back',
    this.description =
        'Sign in to continue your journey and discover meaningful events.',
  });

  final String heading;
  final String description;

  static const _imageUrl =
      'https://images.unsplash.com/photo-1511632765486-a01980e01a18?auto=format&fit=crop&w=1200&q=80&fm=webp';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 1024;
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 24 : 32),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _imageUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) =>
                ColoredBox(color: Color(0xFFFFD9E5)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4A1028).withValues(alpha: isDark ? .6 : .22),
                  Color(0xFF58102F).withValues(alpha: .88),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 28 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(99),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .22)),
                  ),
                  child: Text(context.l10n.khairEvents,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                SizedBox(height: 18),
                Text(
                  heading,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 34 : 48,
                    height: 1.04,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .88),
                      fontSize: compact ? 15 : 17,
                      height: 1.5),
                ),
                SizedBox(height: 28),
                const _ValuePoint(
                    icon: Icons.auto_awesome_rounded,
                    text: 'Find inspiring events'),
                SizedBox(height: 12),
                const _ValuePoint(
                    icon: Icons.groups_2_outlined,
                    text: 'Connect with communities'),
                SizedBox(height: 12),
                const _ValuePoint(
                    icon: Icons.favorite_border_rounded,
                    text: 'Create unforgettable moments'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValuePoint({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Colors.white, size: 19),
        SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ]);
}
