import 'package:flutter/material.dart';
import '../theme/khair_theme.dart';

/// Premium floating toast notifications for Khair.
///
/// Usage:
///   KhairToast.success(context, 'You joined this event!');
///   KhairToast.error(context, 'Something went wrong');
///   KhairToast.info(context, 'Event saved to favorites');
class KhairToast {
  KhairToast._();

  /// 🎉 Success toast (green accent)
  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      emoji: '🎉',
      backgroundColor: KhairColors.success,
      textColor: Colors.white,
    );
  }

  /// ❌ Error toast (red accent)
  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      emoji: '😔',
      backgroundColor: KhairColors.error,
      textColor: Colors.white,
    );
  }

  /// ℹ️ Info toast (blue accent)
  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      emoji: 'ℹ️',
      backgroundColor: KhairColors.info,
      textColor: Colors.white,
    );
  }

  /// ⚠️ Warning toast (amber accent)
  static void warning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      emoji: '⚠️',
      backgroundColor: KhairColors.warning,
      textColor: KhairColors.neutral900,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required String emoji,
    required Color backgroundColor,
    required Color textColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KhairRadius.md),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
        elevation: 6,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
