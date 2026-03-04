import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

enum ResponsiveTier {
  mobile,
  tablet,
  desktop,
}

typedef ResponsiveBuilder = Widget Function(
  BuildContext context,
  ResponsiveTier tier,
);

class ResponsiveLayout extends StatelessWidget {
  final ResponsiveBuilder mobileBuilder;
  final ResponsiveBuilder? tabletBuilder;
  final ResponsiveBuilder? desktopBuilder;

  const ResponsiveLayout({
    super.key,
    required this.mobileBuilder,
    this.tabletBuilder,
    this.desktopBuilder,
  });

  static ResponsiveTier tierForWidth(double width) {
    if (width >= AppBreakpoints.desktop) {
      return ResponsiveTier.desktop;
    }
    if (width >= AppBreakpoints.tablet) {
      return ResponsiveTier.tablet;
    }
    return ResponsiveTier.mobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tier = tierForWidth(constraints.maxWidth);
        switch (tier) {
          case ResponsiveTier.desktop:
            return (desktopBuilder ?? tabletBuilder ?? mobileBuilder)(
                context, tier);
          case ResponsiveTier.tablet:
            return (tabletBuilder ?? mobileBuilder)(context, tier);
          case ResponsiveTier.mobile:
            return mobileBuilder(context, tier);
        }
      },
    );
  }
}
