import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/notification_entity.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../../../core/push/badge_service.dart';
import '../../../../core/services/websocket_service.dart';
import '../notification_toast.dart';

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

class DeleteNotification extends NotificationEvent {
  final String notificationId;
  const DeleteNotification(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class NotificationReceived extends NotificationEvent {
  final AppNotification notification;
  const NotificationReceived(this.notification);

  @override
  List<Object?> get props => [notification];
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
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  int _lastUnreadCount = 0;
  bool _isAuthenticated = false;

  NotificationBloc(this._repository, {bool enablePolling = true})
      : super(const NotificationState()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<NotificationSessionChanged>(_onSessionChanged);
    on<MarkNotificationRead>(_onMarkRead);
    on<MarkAllNotificationsRead>(_onMarkAllRead);
    on<NotificationReceived>(_onNotificationReceived);
    on<DeleteNotification>(_onDeleteNotification);
    WidgetsBinding.instance.addObserver(this);
    _realtimeSubscription = WebSocketService.instance.messages.listen(
      _onRealtimeMessage,
    );

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
    _realtimeSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  void _onRealtimeMessage(Map<String, dynamic> envelope) {
    if (!_isAuthenticated || envelope['type'] != 'notification.created') {
      return;
    }
    final raw = envelope['data'];
    if (raw is! Map) return;
    final data = Map<String, dynamic>.from(raw);
    final notification = AppNotification.fromJson({
      'id': data['notification_id'] ?? data['id'] ?? '',
      'user_id': data['user_id'] ?? '',
      'title': data['title'] ?? '',
      'message': data['message'] ?? '',
      'notification_type': data['type'] ?? 'general',
      'data': data,
      'is_read': false,
      'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
    });
    if (notification.title.trim().isEmpty &&
        notification.message.trim().isEmpty) {
      return;
    }
    add(NotificationReceived(notification));
  }

  void _onNotificationReceived(
    NotificationReceived event,
    Emitter<NotificationState> emit,
  ) {
    final notification = event.notification;
    if (state.notifications.any(
        (item) => item.id == notification.id && notification.id.isNotEmpty)) {
      return;
    }
    final updated = [notification, ...state.notifications];
    if (updated.length > 50) updated.removeLast();
    final unread = updated.where((item) => !item.isRead).length;
    _lastUnreadCount = unread;
    BadgeService.instance.updateBadge(unread);
    emit(state.copyWith(
      status: NotificationStatus.success,
      notifications: updated,
      unreadCount: unread,
    ));
    NotificationToast.show(notification);
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
            return n.copyWith(isRead: true);
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
          return n.copyWith(isRead: true);
        }).toList();
        BadgeService.instance.clearBadge();
        emit(state.copyWith(
          notifications: updated,
          unreadCount: 0,
        ));
      },
    );
  }

  Future<void> _onDeleteNotification(
    DeleteNotification event,
    Emitter<NotificationState> emit,
  ) async {
    if (!_isAuthenticated) return;
    final result = await _repository.deleteNotification(event.notificationId);
    result.fold((_) {}, (_) {
      final updated = state.notifications
          .where((notification) => notification.id != event.notificationId)
          .toList();
      final unread =
          updated.where((notification) => !notification.isRead).length;
      BadgeService.instance.updateBadge(unread);
      emit(state.copyWith(notifications: updated, unreadCount: unread));
    });
  }
}
