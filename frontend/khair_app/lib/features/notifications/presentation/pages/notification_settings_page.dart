import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/push/push_notification_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../../tokens/tokens.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _api = getIt<ApiClient>();
  Map<String, bool> _values = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _api.get('/notification-preferences');
      final raw = response.data is Map ? response.data['data'] : null;
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _values = {
          for (final key in _keys) key: data[key] != false,
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.failedToLoadNotifications;
      });
    }
  }

  Future<void> _set(String key, bool value) async {
    final previous = _values[key] ?? true;
    setState(() {
      _values = {..._values, key: value};
      _saving = true;
      _error = null;
    });
    try {
      await _api.patch('/notification-preferences', data: _values);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.notificationSaved)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _values = {..._values, key: previous};
        _saving = false;
        _error = context.l10n.notificationSaveFailed;
      });
    }
  }

  Future<void> _enableBrowserPush() async {
    final granted = await PushNotificationService.instance.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(granted
          ? context.l10n.notificationSaved
          : context.l10n.notificationSaveFailed),
    ));
    if (granted && !(_values['browser_push'] ?? true)) {
      await _set('browser_push', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.x3),
                children: [
                  Text(l10n.notificationTopics,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.x1),
                  _switch(l10n.notificationMessagesTopic, 'messages'),
                  _switch(l10n.notificationEventRegistrationsTopic,
                      'event_registrations'),
                  _switch(l10n.notificationEventUpdatesTopic, 'event_updates'),
                  _switch(
                      l10n.notificationEventRemindersTopic, 'event_reminders'),
                  _switch(l10n.notificationOrganizerAnnouncementsTopic,
                      'organizer_announcements'),
                  _switch(l10n.notificationSystemTopic, 'system_notifications'),
                  const Divider(height: 30),
                  _switch(l10n.notificationBrowserPush, 'browser_push'),
                  _switch(l10n.notificationEmailTopic, 'email_notifications'),
                  const SizedBox(height: AppSpacing.x2),
                  OutlinedButton.icon(
                    onPressed: _enableBrowserPush,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(l10n.notificationEnableBrowserPush),
                  ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _switch(String title, String key) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: _values[key] ?? true,
        onChanged: _saving ? null : (value) => _set(key, value),
      );
}

const _keys = <String>[
  'messages',
  'event_registrations',
  'event_updates',
  'event_reminders',
  'organizer_announcements',
  'system_notifications',
  'browser_push',
  'email_notifications',
];
