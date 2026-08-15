import 'package:flutter/widgets.dart';

/// Shared layout thresholds for Khair's adaptive product surfaces.
///
/// Keep responsive decisions here rather than scattering one-off width checks
/// through pages. The homepage uses distinct mobile, tablet, and desktop
/// compositions at these boundaries.
abstract final class AppBreakpoints {
  static const smallMobile = 360.0;
  static const mobile = 600.0;
  static const tablet = 1024.0;
  static const desktop = 1440.0;

  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < smallMobile;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}
