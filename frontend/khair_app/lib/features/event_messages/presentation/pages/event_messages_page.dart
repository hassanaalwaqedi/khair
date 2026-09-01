import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/di/injection.dart';
import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:khair_app/core/network/api_client.dart';

/// API-backed event conversations. This page deliberately has no local/mock
/// conversation store: the server is the authority for membership and safety.
class EventMessagesPage extends StatefulWidget {
  const EventMessagesPage(
      {super.key, this.conversationId, this.eventId, this.attendeeId});
  final String? conversationId;
  final String? eventId;
  final String? attendeeId;
  @override
  State<EventMessagesPage> createState() => _EventMessagesPageState();
}

class _EventMessagesPageState extends State<EventMessagesPage> {
  final _api = getIt<ApiClient>();
  final _text = TextEditingController();
  List<dynamic> _items = [];
  List<dynamic> _messages = [];
  String? _id;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _id = widget.conversationId;
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_id == null && widget.eventId != null) {
        final r = await _api.post('/event-messages/conversations', data: {
          'event_id': widget.eventId,
          if (widget.attendeeId != null) 'attendee_id': widget.attendeeId
        });
        _id = r.data['data']['id'].toString();
      }
      if (_id == null) {
        final r = await _api.get('/event-messages/conversations');
        _items = (r.data['data'] as List?) ?? [];
      } else {
        final r = await _api.get('/event-messages/conversations/$_id/messages');
        _messages = (r.data['data'] as List?) ?? [];
      }
      _error = null;
    } catch (_) {
      _error = 'Unable to load messages. Check your connection and try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final b = _text.text.trim();
    if (b.isEmpty || _id == null) return;
    try {
      final r = await _api.post('/event-messages/conversations/$_id/messages',
          data: {'body': b});
      if (r.data['data']?['requires_risk_confirmation'] == true) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Review message'),
                  content: Text(r.data['data']?['warning']?.toString() ??
                      'This message may contain sensitive content.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Send anyway')),
                  ],
                ));
        if (confirmed != true) return;
        await _api.post('/event-messages/conversations/$_id/messages',
            data: {'body': b, 'confirm_risk': true});
      }
      if (!mounted) {
        return;
      }
      _text.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message could not be sent.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Text(_id == null ? context.l10n.messages : 'Event conversation'),
          actions: [
            if (_id == null)
              IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh)),
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Try again'))
                ]))
              : _id == null
                  ? _list()
                  : _chat());
  Widget _list() => RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 150),
              Icon(Icons.forum_outlined, size: 48),
              SizedBox(height: 16),
              Center(child: Text('No event conversations yet.')),
              SizedBox(height: 8),
              Center(
                  child: Text(
                      'Messages will appear here after you contact an organizer or attendee.')),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (c, i) {
                final x = _items[i] as Map;
                final unread = (x['unread_count'] as num?)?.toInt() ?? 0;
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                        child: Icon(unread > 0
                            ? Icons.mark_chat_unread_outlined
                            : Icons.event_outlined)),
                    title: Text(x['event_title']?.toString() ?? 'Event',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(unread > 0
                        ? '$unread unread ${unread == 1 ? 'message' : 'messages'}'
                        : 'Open event conversation'),
                    trailing: unread > 0
                        ? CircleAvatar(
                            radius: 12,
                            child: Text('$unread',
                                style: const TextStyle(fontSize: 12)))
                        : const Icon(Icons.chevron_right),
                    onTap: () => context.push('/event-messages/${x['id']}'),
                  ),
                );
              }));
  Widget _chat() => Column(children: [
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Messages are limited to people connected to this event.',
                textAlign: TextAlign.center)),
        Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Start the event conversation.'))
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (c, i) {
                      final x = _messages[i] as Map;
                      return ListTile(
                          title: Text(x['body'] ?? ''),
                          subtitle: Text(x['created_at'] ?? ''));
                    })),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _text,
                      maxLength: 4000,
                      decoration:
                          const InputDecoration(hintText: 'Write a message'))),
              IconButton(onPressed: _send, icon: const Icon(Icons.send))
            ]))
      ]);
}
