import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final dio = getIt<Dio>();
      final responses = await Future.wait([
        dio.get('/notifications'),
        dio.get('/notifications/unread-count'),
      ]);

      final list = responses[0].data['data'];
      final countData = responses[1].data['data'];

      setState(() {
        _notifications = list is List
            ? List<Map<String, dynamic>>.from(list)
            : [];
        _unreadCount = countData?['unread_count'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    try {
      final dio = getIt<Dio>();
      await dio.put('/notifications/$id/read');
      setState(() {
        _notifications[index]['is_read'] = true;
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final dio = getIt<Dio>();
      await dio.put('/notifications/read-all');
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = true;
        }
        _unreadCount = 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_unreadCount > 0
            ? 'Notifications ($_unreadCount new)'
            : 'Notifications'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) =>
                        _buildNotificationCard(_notifications[index], index),
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, int index) {
    final isRead = notif['is_read'] == true;
    final title = notif['title'] ?? '';
    final message = notif['message'] ?? '';
    final createdAt =
        DateTime.tryParse(notif['created_at'] ?? '') ?? DateTime.now();
    final id = notif['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (!isRead) _markAsRead(id, index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? Theme.of(context).cardTheme.color
              : AppTheme.primaryColor.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? Colors.grey.withAlpha(51)
                : AppTheme.primaryColor.withAlpha(77),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isRead
                    ? Colors.grey.withAlpha(26)
                    : AppTheme.primaryColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getNotifIcon(title),
                color: isRead ? Colors.grey : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('MMM d, y • HH:mm').format(createdAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getNotifIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('joined') || t.contains('registration')) {
      return Icons.event_available;
    }
    if (t.contains('reminder')) return Icons.alarm;
    if (t.contains('participant')) return Icons.person_add;
    if (t.contains('approved')) return Icons.check_circle;
    if (t.contains('warning') || t.contains('suspended')) return Icons.warning;
    return Icons.notifications;
  }
}
