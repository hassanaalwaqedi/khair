import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Cross-platform share helper.
/// Uses native share on mobile, falls back to clipboard + snackbar on web/desktop.
class ShareHelper {
  ShareHelper._();

  /// Share text. On web/desktop where native share may not work,
  /// copies to clipboard and shows a snackbar instead.
  static Future<void> share(BuildContext context, String text) async {
    // On web, Web Share API only works on HTTPS — fall back to clipboard
    if (kIsWeb) {
      try {
        final result = await SharePlus.instance.share(
          ShareParams(text: text),
        );
        // If share was successful, return
        if (result.status == ShareResultStatus.success) return;
      } catch (_) {
        // Web Share API not available — fall through to clipboard
      }
      _copyToClipboard(context, text);
      return;
    }

    // Mobile / desktop: use native share
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      _copyToClipboard(context, text);
    }
  }

  static void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Link copied to clipboard!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
