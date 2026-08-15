import 'package:flutter/material.dart';

/// Login layout breakpoints used by every auth component.
class AuthBreakpoints {
  AuthBreakpoints._();

  static const mobile = 600.0;
  static const visualPanel = 768.0;
  static const desktop = 1024.0;
  static const largeDesktop = 1440.0;
}

class AuthMetrics {
  final double width;
  const AuthMetrics(this.width);

  bool get isMobile => width < AuthBreakpoints.mobile;
  bool get showsVisualPanel => width >= AuthBreakpoints.visualPanel;
  bool get isDesktop => width >= AuthBreakpoints.desktop;
  bool get isLargeDesktop => width >= AuthBreakpoints.largeDesktop;

  double get horizontalPadding => isMobile
      ? 20
      : isDesktop
          ? 48
          : 32;
  double get titleSize => isMobile
      ? 31
      : isDesktop
          ? 46
          : 38;
  double get bodySize => isMobile ? 15 : 16;
  double get formMaxWidth => isDesktop ? 500 : 520;
  double get sectionGap => isMobile ? 24 : 32;
}

/// A keyboard-safe shell with a dedicated mobile composition and a balanced
/// visual/form split for tablet and desktop.
class AuthResponsiveShell extends StatelessWidget {
  final Widget topBar;
  final Widget form;
  final Widget visualPanel;

  const AuthResponsiveShell({
    super.key,
    required this.topBar,
    required this.form,
    required this.visualPanel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AuthMetrics(constraints.maxWidth);
        if (!metrics.showsVisualPanel) {
          return SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                metrics.horizontalPadding,
                12,
                metrics.horizontalPadding,
                32 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [topBar, const SizedBox(height: 24), form],
              ),
            ),
          );
        }

        final visualFlex = metrics.isDesktop ? 5 : 4;
        return SafeArea(
          minimum: EdgeInsets.all(metrics.isDesktop ? 24 : 16),
          child: Row(
            children: [
              Expanded(flex: visualFlex, child: visualPanel),
              Expanded(
                flex: 6,
                child: LayoutBuilder(
                  builder: (context, rightConstraints) => SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      16,
                      metrics.horizontalPadding,
                      32 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minHeight: rightConstraints.maxHeight - 48),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: metrics.formMaxWidth),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              topBar,
                              SizedBox(height: metrics.isDesktop ? 64 : 40),
                              form,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
