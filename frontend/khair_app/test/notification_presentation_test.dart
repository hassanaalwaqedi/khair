import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:khair_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:khair_app/features/notifications/presentation/notification_presentation.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations ar;
  late AppLocalizations tr;

  setUpAll(() async {
    await initializeDateFormatting();
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  test('English event join confirmation is structured and single-language', () {
    final presentation = NotificationPresentationResolver.resolve(
      _eventJoin(),
      en,
      const Locale('en'),
    );

    expect(presentation.title, en.notificationEventJoinTitle);
    expect(presentation.body, contains('SQL & Victor Database'));
    expect(presentation.body, isNot(contains('تم')));
    expect(presentation.metadata, hasLength(3));
    expect(presentation.metadata[1].text, en.notificationOnline);
    expect(presentation.metadata[2].text, en.notificationFree);
    expect(presentation.eventId, 'event-123');
    expect(presentation.ctaLabel, en.notificationViewEvent);
  });

  test('Arabic event join confirmation localizes system copy only', () {
    final presentation = NotificationPresentationResolver.resolve(
      _eventJoin(),
      ar,
      const Locale('ar'),
    );

    expect(presentation.title, ar.notificationEventJoinTitle);
    expect(presentation.body, contains('SQL & Victor Database'));
    expect(presentation.body, contains('انضممت'));
    expect(presentation.body, isNot(contains("You've successfully joined")));
    expect(presentation.ctaLabel, ar.notificationViewEvent);
  });

  test('Turkish event join confirmation preserves the authored title', () {
    final presentation = NotificationPresentationResolver.resolve(
      _eventJoin(),
      tr,
      const Locale('tr'),
    );

    expect(presentation.title, tr.notificationEventJoinTitle);
    expect(presentation.body, contains('SQL & Victor Database'));
    expect(presentation.body, contains('başarıyla katıldınız'));
    expect(presentation.body, isNot(contains('You')));
  });

  test('paid in-person metadata includes price and public city only', () {
    final notification = _eventJoin(data: {
      'entity_id': 'event-paid',
      'event_id': 'event-paid',
      'event_title': 'Community Dinner',
      'start_at': '2026-08-21T16:00:00Z',
      'event_type': 'in_person',
      'public_location': 'Istanbul',
      'pricing_type': 'paid',
      'price_minor': '550',
      'currency': 'USD',
      'payment_method': 'pay_at_venue',
    });
    final presentation = NotificationPresentationResolver.resolve(
      notification,
      en,
      const Locale('en'),
    );

    expect(presentation.metadata, hasLength(3));
    expect(presentation.metadata[1].text, contains('Istanbul'));
    expect(presentation.metadata[2].text, contains('5.50'));
    expect(presentation.metadata[2].text, contains('Pay at venue'));
  });

  test('legacy notifications remain unchanged when metadata is unavailable',
      () {
    final notification = AppNotification(
      id: 'legacy',
      userId: 'user',
      title: 'Historical title',
      message: 'Historical body',
      isRead: false,
      createdAt: DateTime(2026, 8, 20),
    );
    final presentation = NotificationPresentationResolver.resolve(
      notification,
      ar,
      const Locale('ar'),
    );

    expect(presentation.title, 'Historical title');
    expect(presentation.body, 'Historical body');
    expect(presentation.isStructured, isFalse);
  });
}

AppNotification _eventJoin({Map<String, dynamic>? data}) {
  return AppNotification(
    id: 'notification-123',
    userId: 'user-123',
    title: 'legacy title',
    message: 'legacy body',
    notificationType: 'event_join_confirmed',
    data: data ??
        {
          'entity_type': 'event',
          'entity_id': 'event-123',
          'event_id': 'event-123',
          'event_title': 'SQL & Victor Database',
          'start_at': '2026-08-21T16:00:00Z',
          'timezone': 'Europe/Istanbul',
          'event_type': 'online',
          'pricing_type': 'free',
        },
    isRead: false,
    createdAt: DateTime(2026, 8, 20, 8, 23),
  );
}
