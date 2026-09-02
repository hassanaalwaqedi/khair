import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:khair_app/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../features/events/domain/entities/event.dart';

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
      if (context.mounted) {
        _copyToClipboard(context, text);
      }
      return;
    }

    // Mobile / desktop: use native share
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (context.mounted) {
        _copyToClipboard(context, text);
      }
    }
  }

  /// Specialized method to share a Khair event using clean OpenGraph metadata.
  /// It builds a short localized string containing only the title and canonical URL.
  static Future<void> shareEvent(
      BuildContext context, Event event, String publicUrl) async {
    final l10n = AppLocalizations.of(context)!;

    final List<String> lines = [];
    lines.add(l10n.shareEventIntro(event.title));
    lines.add('');

    // Date & Time
    final locale = Localizations.localeOf(context).languageCode;
    final dateStr = DateFormat.yMMMEd(locale).format(event.startDate);
    final timeStr = DateFormat.jm(locale).format(event.startDate);
    lines.add('📅 $dateStr · $timeStr');

    // Location
    if (event.isOnline) {
      lines.add(l10n.shareEventOnlineLocation);
    } else if (event.city != null) {
      final loc = event.country != null
          ? '${event.city}, ${event.country}'
          : event.city!;
      lines.add(l10n.shareEventPhysicalLocation(loc));
    }

    // Organizer
    if (event.organizerName != null && event.organizerName!.trim().isNotEmpty) {
      lines.add(l10n.shareEventOrganizer(event.organizerName!));
    }

    lines.add('');
    lines.add(publicUrl);

    final text = lines.join('\n');
    // Share text only. Attaching an image makes Windows and mobile targets
    // treat the event as a file share, which loses the link preview. The
    // backend's canonical event URL serves per-event Open Graph metadata, so
    // WhatsApp and other clients can render the title, description, and image.
    if (!context.mounted) return;
    await share(context, text);
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
