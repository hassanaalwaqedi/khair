import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khair_app/core/di/injection.dart';
import 'package:khair_app/core/layout/app_breakpoints.dart';
import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:khair_app/core/network/api_client.dart';
import 'package:khair_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:khair_app/tokens/tokens.dart';

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
  String? _eventTitle;
  String? _participantName;
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
    final loadError = context.l10n.messagesLoadError;
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
      _error = loadError;
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
                  title: Text(context.l10n.reviewMessage),
                  content: Text(r.data['data']?['warning']?.toString() ??
                      context.l10n.sensitiveMessageWarning),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.sendAnyway)),
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
            SnackBar(content: Text(context.l10n.messageCouldNotBeSent)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChat = _id != null;
    return Scaffold(
      appBar: isChat ? _chatAppBar(context) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState(context)
              : isChat
                  ? _chat(context)
                  : _inbox(context),
    );
  }

  PreferredSizeWidget _chatAppBar(BuildContext context) => AppBar(
        titleSpacing: 0,
        title: Row(children: [
          _InitialAvatar(
              name: _participantName ?? context.l10n.eventConversation),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(_participantName ?? context.l10n.eventConversation,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_eventTitle ?? context.l10n.eventConversation,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]))
        ]),
        actions: [
          IconButton(
              tooltip: context.l10n.refreshConversation,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: context.l10n.conversationOptions,
              onPressed: () {},
              icon: const Icon(Icons.more_horiz_rounded)),
          const SizedBox(width: 6),
        ],
      );

  Widget _errorState(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.tryAgain)),
          ])));

  Widget _inbox(BuildContext context) {
    final desktop = AppBreakpoints.isDesktop(context);
    return SafeArea(
      top: !desktop,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 18),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(context.l10n.messages,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(context.l10n.privateConversationsFromEvents,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ])),
                        IconButton.filledTonal(
                            tooltip: context.l10n.refreshEvents,
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded)),
                      ]))),
              if (_items.isEmpty)
                const SliverFillRemaining(
                    hasScrollBody: false, child: _InboxEmptyState())
              else
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverList.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index] as Map;
                          return _ConversationRow(
                            item: item,
                            onTap: () {
                              setState(() {
                                _id = item['id']?.toString();
                                _eventTitle = item['event_title']?.toString();
                                _participantName =
                                    item['participant_name']?.toString();
                              });
                              _load();
                            },
                          );
                        }))
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chat(BuildContext context) {
    final myId = getIt<AuthBloc>().state.user?.id;
    return Column(children: [
      Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline_rounded, size: 16),
            const SizedBox(width: 8),
            Text(context.l10n.privateEventConversation,
                style: Theme.of(context).textTheme.labelMedium),
          ])),
      Expanded(
          child: _messages.isEmpty
              ? const _ChatEmptyState()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, reverseIndex) {
                    final item =
                        _messages[_messages.length - 1 - reverseIndex] as Map;
                    return _MessageBubble(
                        message: item,
                        isMine: item['sender_id']?.toString() == myId);
                  })),
      _MessageComposer(controller: _text, onSend: _send),
    ]);
  }
}

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState();

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.forum_outlined,
                    size: 38, color: AppColors.primary)),
            const SizedBox(height: 18),
            Text(context.l10n.noMessagesYet,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(context.l10n.messagesEmptyDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ])));
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.item, required this.onTap});
  final Map item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = (item['unread_count'] as num?)?.toInt() ?? 0;
    final name =
        item['participant_name']?.toString() ?? context.l10n.eventContact;
    final event =
        item['event_title']?.toString() ?? context.l10n.eventConversation;
    final stamp = _shortTime(item['last_message_at']?.toString());
    return Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                child: Row(children: [
                  _InitialAvatar(
                      name: name,
                      imageUrl: item['participant_avatar']?.toString()),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: unread > 0
                                          ? FontWeight.w800
                                          : FontWeight.w700))),
                          if (stamp.isNotEmpty)
                            Text(stamp,
                                style: Theme.of(context).textTheme.labelSmall),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.event_outlined, size: 14),
                          const SizedBox(width: 5),
                          Expanded(
                              child: Text(event,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodySmall)),
                          if (unread > 0) ...[
                            const SizedBox(width: 10),
                            Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text('$unread',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800))),
                          ]
                        ])
                      ]))
                ]))));
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, this.imageUrl});
  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'K' : name.trim()[0].toUpperCase();
    return CircleAvatar(
        radius: 24,
        foregroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? NetworkImage(imageUrl!)
            : null,
        backgroundColor: AppColors.primarySoft,
        child: Text(initial,
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w800)));
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 42),
            const SizedBox(height: 14),
            Text(context.l10n.startConversation,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.l10n.eventQuestionHint,
                style: Theme.of(context).textTheme.bodyMedium),
          ])));
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});
  final Map message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final body = message['body']?.toString() ?? '';
    final stamp = _time(message['created_at']?.toString());
    final scheme = Theme.of(context).colorScheme;
    return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 18))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text(body,
                              style: TextStyle(
                                  color:
                                      isMine ? Colors.white : scheme.onSurface,
                                  height: 1.35))),
                      if (stamp.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(stamp,
                            style: TextStyle(
                                fontSize: 11,
                                color: isMine
                                    ? Colors.white.withValues(alpha: .8)
                                    : scheme.onSurfaceVariant)),
                      ]
                    ]))));
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                  top: BorderSide(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: .5)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                        counterText: '',
                        hintText: context.l10n.writeMessage,
                        prefixIcon: Icon(Icons.add_circle_outline_rounded),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(22)))))),
            const SizedBox(width: 10),
            IconButton.filled(
                tooltip: context.l10n.sendMessageAction,
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded))
          ])));
}

String _time(String? raw) {
  if (raw == null) return '';
  final value = DateTime.tryParse(raw)?.toLocal();
  return value == null ? '' : DateFormat('h:mm a').format(value);
}

String _shortTime(String? raw) {
  if (raw == null) return '';
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return '';
  final now = DateTime.now();
  if (DateUtils.isSameDay(value, now)) {
    return DateFormat('h:mm a').format(value);
  }
  return DateFormat('MMM d').format(value);
}
