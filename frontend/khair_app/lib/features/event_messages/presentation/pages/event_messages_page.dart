import 'package:flutter/material.dart';
import 'package:khair_app/core/di/injection.dart';
import 'package:khair_app/core/network/api_client.dart';

/// API-backed event conversations. This page deliberately has no local/mock
/// conversation store: the server is the authority for membership and safety.
class EventMessagesPage extends StatefulWidget {
  const EventMessagesPage({super.key, this.conversationId, this.eventId});
  final String? conversationId;
  final String? eventId;
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
        final r = await _api.post('/event-messages/conversations',
            data: {'event_id': widget.eventId});
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
      if (r.data['data']?['requires_risk_confirmation'] == true && !mounted)
        return;
      _text.clear();
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message could not be sent.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(_id == null ? 'Event messages' : 'Event conversation')),
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
  Widget _list() => _items.isEmpty
      ? const Center(child: Text('No event conversations yet.'))
      : ListView.builder(
          itemCount: _items.length,
          itemBuilder: (c, i) {
            final x = _items[i] as Map;
            return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.event)),
                title: Text(x['event_title'] ?? 'Event'),
                subtitle: Text((x['unread_count'] ?? 0) > 0
                    ? 'New messages'
                    : 'No unread messages'),
                onTap: () {
                  setState(() {
                    _id = x['id'];
                  });
                  _load();
                });
          });
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
