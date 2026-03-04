import 'package:flutter/material.dart';

import '../../tokens/tokens.dart';
import 'app_breakpoints.dart';
import 'responsive_layout.dart';

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBuilder: (context, _) => Padding(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: AppSpacing.x2,
            ),
        child: child,
      ),
      tabletBuilder: (context, _) => Padding(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x2,
            ),
        child: child,
      ),
      desktopBuilder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.desktopMaxContentWidth,
          ),
          child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}
