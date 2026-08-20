import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';

/// The single in-app representation of Khair's approved white-K / rose mark.
///
/// The mark asset contains no product name. Use [KhairBrand] wherever a
/// wordmark is appropriate instead of recreating the logo with an icon or text.
class KhairBrandMark extends StatelessWidget {
  const KhairBrandMark({
    super.key,
    this.size = 32,
    this.decorative = false,
  });

  static const asset = 'assets/branding/khair_logo_primary.png';

  final double size;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    return decorative
        ? ExcludeSemantics(child: image)
        : Semantics(label: context.l10n.appTitle, image: true, child: image);
  }
}

/// A consistent product lockup for headers, authentication, and platform UI.
class KhairBrand extends StatelessWidget {
  const KhairBrand({
    super.key,
    this.size = 32,
    this.showName = true,
    this.gap = 8,
    this.nameStyle,
  });

  final double size;
  final bool showName;
  final double gap;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    if (!showName) {
      return KhairBrandMark(size: size);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KhairBrandMark(size: size, decorative: true),
        SizedBox(width: gap),
        Text(
          'Khair',
          style: nameStyle ??
              Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
        ),
      ],
    );
  }
}
