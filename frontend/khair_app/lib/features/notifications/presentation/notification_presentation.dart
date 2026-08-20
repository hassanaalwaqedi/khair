import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:khair_app/l10n/generated/app_localizations.dart';

import '../domain/entities/notification_entity.dart';

/// A localized row shown only when the structured notification has a value.
class NotificationMetadataRow {
  final IconData icon;
  final String text;

  const NotificationMetadataRow({required this.icon, required this.text});
}

/// Presentation-ready notification content.
///
/// New notification types are rendered here from stable type + metadata. A
/// legacy record with only title/message is returned unchanged so historical
/// notifications remain readable and are never guessed or parsed.
class NotificationPresentation {
  final String title;
  final String body;
  final List<NotificationMetadataRow> metadata;
  final String? eventId;
  final String? ctaLabel;
  final bool isStructured;

  const NotificationPresentation({
    required this.title,
    required this.body,
    this.metadata = const [],
    this.eventId,
    this.ctaLabel,
    this.isStructured = false,
  });

  bool get hasAction => eventId != null && ctaLabel != null;
}

class NotificationPresentationResolver {
  const NotificationPresentationResolver._();

  static NotificationPresentation resolve(
    AppNotification notification,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final data = notification.data;
    final type = notification.notificationType;

    if (_isEventJoin(type) && _hasValue(data['event_title'])) {
      return _resolveEventJoin(data, l10n, locale);
    }

    if (_isParticipantUpdate(type) && _hasValue(data['event_title'])) {
      final eventId = _eventId(data);
      return NotificationPresentation(
        title: l10n.notificationEventParticipantJoinedTitle,
        body: l10n.notificationEventParticipantJoinedBody(
          data['event_title']!.toString(),
        ),
        eventId: eventId,
        ctaLabel: eventId == null ? null : l10n.notificationViewEvent,
        isStructured: true,
      );
    }

    if (type == 'event_reminder' && _hasValue(data['event_title'])) {
      return NotificationPresentation(
        title: l10n.notificationEventReminderTitle,
        body: l10n.notificationEventReminderBody(
          data['event_title']!.toString(),
          data['reminder_label']?.toString() ?? '',
        ),
        eventId: _eventId(data),
        ctaLabel: _eventId(data) == null ? null : l10n.notificationViewEvent,
        isStructured: true,
      );
    }

    if (type == 'welcome' && _hasValue(data['first_name'])) {
      final firstName = data['first_name']!.toString();
      final underReview = _isUnderReviewRole(data['role']?.toString());
      return NotificationPresentation(
        title: underReview
            ? l10n.notificationWelcomeUnderReviewTitle
            : l10n.notificationWelcomeTitle,
        body: underReview
            ? l10n.notificationWelcomeUnderReviewBody(firstName)
            : l10n.notificationWelcomeBody(firstName),
        isStructured: true,
      );
    }

    return NotificationPresentation(
      title: notification.title,
      body: notification.message,
    );
  }

  static NotificationPresentation _resolveEventJoin(
    Map<String, dynamic> data,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final eventId = _eventId(data);
    final eventTitle = data['event_title']!.toString();
    final metadata = <NotificationMetadataRow>[];
    final localStart = data['event_local_start']?.toString();
    final startAt = DateTime.tryParse(
      (localStart == null || localStart.trim().isEmpty)
          ? (data['start_at']?.toString() ?? '')
          : localStart,
    );

    if (startAt != null) {
      final displayTime = localStart == null ? startAt.toLocal() : startAt;
      final date = DateFormat.yMMMEd(locale.languageCode).format(displayTime);
      final time = DateFormat.jm(locale.languageCode).format(displayTime);
      metadata.add(NotificationMetadataRow(
        icon: Icons.event_outlined,
        text: '$date · $time',
      ));
    }

    if (data['event_type']?.toString() == 'online') {
      metadata.add(NotificationMetadataRow(
        icon: Icons.language_outlined,
        text: l10n.notificationOnline,
      ));
    } else if (_hasValue(data['public_location'])) {
      metadata.add(NotificationMetadataRow(
        icon: Icons.location_on_outlined,
        text: l10n.notificationLocation(data['public_location']!.toString()),
      ));
    }

    final pricingType = data['pricing_type']?.toString();
    if (pricingType == 'free') {
      metadata.add(NotificationMetadataRow(
        icon: Icons.confirmation_number_outlined,
        text: l10n.notificationFree,
      ));
    } else if (pricingType == 'paid') {
      final price = _formatPrice(data, locale);
      if (price != null &&
          data['payment_method']?.toString() == 'pay_at_venue') {
        metadata.add(NotificationMetadataRow(
          icon: Icons.confirmation_number_outlined,
          text: l10n.notificationPayAtVenue(price),
        ));
      }
    }

    return NotificationPresentation(
      title: l10n.notificationEventJoinTitle,
      body: l10n.notificationEventJoinBody(eventTitle),
      metadata: metadata,
      eventId: eventId,
      ctaLabel: eventId == null ? null : l10n.notificationViewEvent,
      isStructured: true,
    );
  }

  static String? formatReceivedAt(
    DateTime createdAt,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final date = DateFormat.yMMMd(locale.languageCode).format(
      createdAt.toLocal(),
    );
    final time = DateFormat.jm(locale.languageCode).format(createdAt.toLocal());
    return l10n.notificationReceivedAt('$date · $time');
  }

  static String? _formatPrice(Map<String, dynamic> data, Locale locale) {
    final minor = int.tryParse(data['price_minor']?.toString() ?? '');
    final currency = data['currency']?.toString().trim();
    if (minor == null || minor <= 0 || currency == null || currency.isEmpty) {
      return null;
    }

    try {
      final decimals = minor % 100 == 0 ? 0 : 2;
      return NumberFormat.simpleCurrency(
        locale: locale.languageCode,
        name: currency,
        decimalDigits: decimals,
      ).format(minor / 100);
    } catch (_) {
      return null;
    }
  }

  static String? _eventId(Map<String, dynamic> data) {
    final value = data['entity_id'] ?? data['event_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  static bool _hasValue(dynamic value) =>
      value != null && value.toString().trim().isNotEmpty;

  static bool _isEventJoin(String type) =>
      type == 'event_join_confirmed' || type == 'event_joined';

  static bool _isParticipantUpdate(String type) =>
      type == 'event_participant_joined' || type == 'new_participant';

  static bool _isUnderReviewRole(String? role) =>
      role == 'sheikh' ||
      role == 'organization' ||
      role == 'community_organizer';
}
