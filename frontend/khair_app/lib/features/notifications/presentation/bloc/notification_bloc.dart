import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/notification_entity.dart';
import '../../data/repositories/notification_repository_impl.dart';

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

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;
  Timer? _pollTimer;
  int _lastUnreadCount = 0;

  NotificationBloc(this._repository) : super(const NotificationState()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<MarkNotificationRead>(_onMarkRead);
    on<MarkAllNotificationsRead>(_onMarkAllRead);

    // Start periodic polling for new notifications
    _pollTimer = Timer.periodic(_notifPollInterval, (_) {
      if (!isClosed) add(const LoadUnreadCount());
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(status: NotificationStatus.loading));

    final result = await _repository.getNotifications();

    result.fold(
      (failure) => emit(state.copyWith(
        status: NotificationStatus.failure,
        errorMessage: failure.message,
      )),
      (notifications) {
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
    final result = await _repository.getUnreadCount();
    result.fold(
      (failure) {
        // Silently ignore auth failures — user not logged in
        // Reset count to 0 to avoid stale badge
        if (state.unreadCount != 0) {
          emit(state.copyWith(unreadCount: 0));
        }
      },
      (count) {
        emit(state.copyWith(unreadCount: count));
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
              isRead: true,
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
        final unread = updated.where((n) => !n.isRead).length;
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
        emit(state.copyWith(
          notifications: updated,
          unreadCount: 0,
        ));
      },
    );
  }
}
