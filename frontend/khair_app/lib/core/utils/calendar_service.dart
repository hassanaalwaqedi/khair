import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/events/domain/entities/event.dart';
import '../config/api_config.dart';

class CalendarService {
  CalendarService._();

  /// Opens Google Calendar to add the given event.
  /// If [authorizedMeetingUrl] is provided, it is included in the calendar description.
  static Future<void> openGoogleCalendar(
    BuildContext context,
    Event event, {
    String? authorizedMeetingUrl,
  }) async {
    final url = buildGoogleCalendarUrl(event, authorizedMeetingUrl);

    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        _showError(context);
      }
    } catch (_) {
      _showError(context);
    }
  }

  /// Builds a Google Calendar event creation URL.
  static String buildGoogleCalendarUrl(
      Event event, String? authorizedMeetingUrl) {
    final startUtc = event.startDate.toUtc();
    final endUtc = event.endDate?.toUtc() ?? startUtc.add(const Duration(hours: 1));

    final startStr = _formatDateUtc(startUtc);
    final endStr = _formatDateUtc(endUtc);

    final title = event.title;

    final List<String> descParts = [];
    if (event.description != null && event.description!.isNotEmpty) {
      descParts.add(event.description!);
    }
    
    if (event.organizerName != null) {
      descParts.add('\nOrganizer: ${event.organizerName}');
    }

    final publicUrl = ApiConfig.publicEventUrl(event.id);
    descParts.add('\nView event on Khair:\n$publicUrl');

    if (authorizedMeetingUrl != null && authorizedMeetingUrl.isNotEmpty) {
      descParts.add('\nJoin meeting:\n$authorizedMeetingUrl');
    }

    final description = descParts.join('\n').trim();

    String location = '';
    if (event.isOnline || event.eventType.toLowerCase().contains('online')) {
      location = event.onlinePlatform ?? 'Online';
    } else {
      final locParts = [
        event.venueName,
        event.address,
        event.city,
        event.country
      ].where((s) => s != null && s.isNotEmpty).toList();
      location = locParts.join(', ');
    }

    final Uri calendarUri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '$startStr/$endStr',
      'details': description,
      'location': location,
    });

    return calendarUri.toString();
  }

  static String _formatDateUtc(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}T'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}Z';
  }

  static void _showError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'We couldn\'t open Google Calendar.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
