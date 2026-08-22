import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/notification_entity.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../../../core/push/badge_service.dart';

const _notifPollInterval = Duration(seconds: 10);

// ── Events ──

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationEvent {
  const LoadNotifications();
}

class LoadUnreadCount extends NotificationEvent {
  const LoadUnreadCount();
}

class NotificationSessionChanged extends NotificationEvent {
  final bool isAuthenticated;
  const NotificationSessionChanged(this.isAuthenticated);

  @override
  List<Object?> get props => [isAuthenticated];
}

class MarkNotificationRead extends NotificationEvent {
  final String notificationId;
  const MarkNotificationRead(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsRead extends NotificationEvent {
  const MarkAllNotificationsRead();
}

// ── State ──

enum NotificationStatus { initial, loading, success, failure }

class NotificationState extends Equatable {
  final NotificationStatus status;
  final List<AppNotification> notifications;
  final int unreadCount;
  final String? errorMessage;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  NotificationState copyWith({
    NotificationStatus? status,
    List<AppNotification>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, notifications, unreadCount, errorMessage];
}

// ── BLoC ──

class NotificationBloc extends Bloc<NotificationEvent, NotificationState>
    with WidgetsBindingObserver {
  final NotificationRepository _repository;
  Timer? _pollTimer;
  int _lastUnreadCount = 0;
  bool _isAuthenticated = false;

  NotificationBloc(this._repository, {bool enablePolling = true})
      : super(const NotificationState()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<NotificationSessionChanged>(_onSessionChanged);
    on<MarkNotificationRead>(_onMarkRead);
    on<MarkAllNotificationsRead>(_onMarkAllRead);
    WidgetsBinding.instance.addObserver(this);

    if (enablePolling) {
      // Start periodic polling for new notifications.
      _pollTimer = Timer.periodic(_notifPollInterval, (_) {
        if (!isClosed) add(const LoadUnreadCount());
      });
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticated && !isClosed) {
      add(const LoadUnreadCount());
    }
  }

  void _onSessionChanged(
    NotificationSessionChanged event,
    Emitter<NotificationState> emit,
  ) {
    _isAuthenticated = event.isAuthenticated;
    _lastUnreadCount = 0;
    if (!_isAuthenticated) {
      BadgeService.instance.clearBadge();
      emit(const NotificationState());
      return;
    }
    add(const LoadUnreadCount());
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    if (!_isAuthenticated) return;
    emit(state.copyWith(status: NotificationStatus.loading));

    final result = await _repository.getNotifications();

    result.fold(
      (failure) {
        dev.log('[NotifBloc] LoadNotifications FAILED: ${failure.message}');
        emit(state.copyWith(
          status: NotificationStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (notifications) {
        dev.log(
            '[NotifBloc] LoadNotifications OK: ${notifications.length} items');
        final unread = notifications.where((n) => !n.isRead).length;
        emit(state.copyWith(
          status: NotificationStatus.success,
          notifications: notifications,
          unreadCount: unread,
        ));
      },
    );
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    if (!_isAuthenticated) return;
    final result = await _repository.getUnreadCount();
    result.fold(
      (failure) {
        // Silently ignore auth failures — user not logged in
        // Reset count to 0 to avoid stale badge
        if (state.unreadCount != 0) {
          BadgeService.instance.clearBadge();
          emit(state.copyWith(unreadCount: 0));
        }
      },
      (count) {
        emit(state.copyWith(unreadCount: count));
        BadgeService.instance.updateBadge(count);
        // If count changed, auto-fetch full notifications
        if (count != _lastUnreadCount) {
          _lastUnreadCount = count;
          if (count > 0) {
            add(const LoadNotifications());
          }
        }
      },
    );
  }

  Future<void> _onMarkRead(
    MarkNotificationRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (!_isAuthenticated) return;
    final result = await _repository.markAsRead(event.notificationId);
    result.fold(
      (_) {},
      (_) {
        final updated = state.notifications.map((n) {
          if (n.id == event.notificationId) {
            return AppNotification(
              id: n.id,
              userId: n.userId,
              title: n.title,
              message: n.message,
              notificationType: n.notificationType,
              data: n.data,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
        final unread = updated.where((n) => !n.isRead).length;
        BadgeService.instance.updateBadge(unread);
        emit(state.copyWith(
          notifications: updated,
          unreadCount: unread,
        ));
      },
    );
  }

  Future<void> _onMarkAllRead(
    MarkAllNotificationsRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (!_isAuthenticated) return;
    final result = await _repository.markAllRead();
    result.fold(
      (_) {},
      (_) {
        final updated = state.notifications.map((n) {
          return AppNotification(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
        BadgeService.instance.clearBadge();
        emit(state.copyWith(
          notifications: updated,
          unreadCount: 0,
        ));
      },
    );
  }
}
