import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khair_app/core/error/failures.dart';
import 'package:khair_app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:khair_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:khair_app/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:khair_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bell shows real unread counts with a 99+ cap', (tester) async {
    final repository = _FakeNotificationRepository();
    final bloc = NotificationBloc(repository, enablePolling: false);
    addTearDown(() async => bloc.close());

    await _pumpBell(tester, bloc);
    expect(find.text('1'), findsNothing);

    repository.unreadCount = 1;
    repository.notifications = [_notification('one', isRead: false)];
    bloc.add(const LoadUnreadCount());
    await tester.pump();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    repository.unreadCount = 15;
    repository.notifications = List.generate(
      15,
      (index) => _notification('$index', isRead: false),
    );
    bloc.add(const LoadUnreadCount());
    await tester.pump();
    await tester.pump();
    expect(find.text('15'), findsOneWidget);

    repository.unreadCount = 100;
    repository.notifications = List.generate(
      100,
      (index) => _notification('$index', isRead: false),
    );
    bloc.add(const LoadUnreadCount());
    await tester.pump();
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('100'), findsNothing);
  });

  testWidgets('bell opens the supplied notification action', (tester) async {
    final bloc = NotificationBloc(
      _FakeNotificationRepository(),
      enablePolling: false,
    );
    addTearDown(() async => bloc.close());
    var tapped = false;

    await tester.pumpWidget(
      _localizedApp(
        BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: NotificationBellButton(onPressed: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    expect(tapped, isTrue);
  });

  test('marking notifications read synchronizes the badge state', () async {
    final repository = _FakeNotificationRepository()
      ..notifications = [
        _notification('one', isRead: false),
        _notification('two', isRead: true),
      ];
    final bloc = NotificationBloc(repository, enablePolling: false);
    addTearDown(() async => bloc.close());

    bloc.add(const NotificationSessionChanged(true));
    await bloc.stream.firstWhere((state) => state.unreadCount == 0);
    bloc.add(const LoadNotifications());
    await bloc.stream.firstWhere((state) => state.unreadCount == 1);

    bloc.add(const MarkNotificationRead('one'));
    await bloc.stream.firstWhere((state) => state.unreadCount == 0);

    bloc.add(const LoadNotifications());
    await bloc.stream.firstWhere((state) => state.unreadCount == 1);
    bloc.add(const MarkAllNotificationsRead());
    await bloc.stream.firstWhere((state) => state.unreadCount == 0);
  });

  test('guest notification state does not call the authenticated API',
      () async {
    final repository = _FakeNotificationRepository();
    final bloc = NotificationBloc(repository, enablePolling: false);
    addTearDown(() async => bloc.close());

    bloc.add(const LoadUnreadCount());
    await Future<void>.delayed(Duration.zero);

    expect(repository.unreadCountCalls, 0);
  });
}

Future<void> _pumpBell(
  WidgetTester tester,
  NotificationBloc bloc, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    _localizedApp(
      BlocProvider.value(
        value: bloc,
        child: const Scaffold(body: NotificationBellButton()),
      ),
      locale: locale,
    ),
  );
  bloc.add(const NotificationSessionChanged(true));
  await tester.pump();
  await tester.pump();
}

Widget _localizedApp(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

AppNotification _notification(String id, {required bool isRead}) {
  return AppNotification(
    id: id,
    userId: 'user',
    title: id,
    message: id,
    isRead: isRead,
    createdAt: DateTime(2026, 1, 1),
  );
}

class _FakeNotificationRepository implements NotificationRepository {
  int unreadCount = 0;
  int unreadCountCalls = 0;
  List<AppNotification> notifications = const [];

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications() async =>
      Right(notifications);

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    unreadCountCalls++;
    return Right(unreadCount);
  }

  @override
  Future<Either<Failure, void>> markAsRead(String id) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> markAllRead() async => const Right(null);
}
