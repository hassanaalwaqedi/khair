import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/khair_theme.dart';

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

  void _openNotification(Map<String, dynamic> notif, int index) {
    final isRead = notif['is_read'] == true;
    final id = notif['id']?.toString() ?? '';
    if (!isRead) _markAsRead(id, index);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationDetailSheet(notif: notif),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1E) : const Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.notifications_rounded,
                color: KhairColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              _unreadCount > 0
                  ? 'Notifications ($_unreadCount)'
                  : 'Notifications',
              style: KhairTypography.headlineSmall.copyWith(
                color: isDark ? Colors.white : KhairColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Read all'),
              style: TextButton.styleFrom(
                foregroundColor: KhairColors.primary,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: KhairColors.primary))
          : _notifications.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  color: KhairColors.primary,
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) =>
                        _buildNotificationCard(_notifications[index], index, isDark),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: KhairColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                size: 40, color: KhairColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: KhairTypography.labelLarge.copyWith(
              color: isDark ? Colors.white70 : KhairColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You\'re all caught up!',
            style: KhairTypography.bodySmall.copyWith(
              color: KhairColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notif, int index, bool isDark) {
    final isRead = notif['is_read'] == true;
    final title = notif['title'] ?? '';
    final message = notif['message'] ?? '';
    final createdAt =
        DateTime.tryParse(notif['created_at'] ?? '') ?? DateTime.now();

    return GestureDetector(
      onTap: () => _openNotification(notif, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? (isRead ? const Color(0xFF1A1A2E) : const Color(0xFF1E2A3A))
              : (isRead ? Colors.white : KhairColors.primary.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15))
                : KhairColors.primary.withValues(alpha: 0.2),
            width: isRead ? 0.5 : 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Khair logo avatar
            _KhairAvatar(isRead: isRead),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender label
                  Text(
                    'Khair',
                    style: KhairTypography.labelSmall.copyWith(
                      color: KhairColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: KhairTypography.labelMedium.copyWith(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: isDark ? Colors.white : KhairColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: KhairTypography.bodySmall.copyWith(
                      color: isDark ? Colors.white60 : KhairColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: KhairColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y • HH:mm').format(createdAt),
                        style: KhairTypography.labelSmall.copyWith(
                          color: KhairColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Unread dot
            if (!isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: KhairColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: KhairColors.primary.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Khair Logo Avatar ─────────────────────────

class _KhairAvatar extends StatelessWidget {
  final bool isRead;
  const _KhairAvatar({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRead
              ? [Colors.grey[400]!, Colors.grey[500]!]
              : [KhairColors.primary, const Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isRead
            ? null
            : [
                BoxShadow(
                  color: KhairColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: const Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Notification Detail Sheet ──────────────────

class _NotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotificationDetailSheet({required this.notif});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = notif['title'] ?? '';
    final message = notif['message'] ?? '';
    final createdAt =
        DateTime.tryParse(notif['created_at'] ?? '') ?? DateTime.now();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header with Khair branding
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  // Khair logo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [KhairColors.primary, Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: KhairColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'K',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khair',
                          style: KhairTypography.headlineSmall.copyWith(
                            color: KhairColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13, color: KhairColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('EEEE, MMM d, y • HH:mm')
                                  .format(createdAt),
                              style: KhairTypography.labelSmall.copyWith(
                                color: KhairColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: isDark ? Colors.white54 : Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDark ? Colors.white10 : Colors.grey[200],
              height: 1,
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                title,
                style: KhairTypography.h2.copyWith(
                  color: isDark ? Colors.white : KhairColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Message body
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Text(
                message,
                style: KhairTypography.bodyLarge.copyWith(
                  color: isDark ? Colors.white70 : KhairColors.textSecondary,
                  height: 1.7,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
