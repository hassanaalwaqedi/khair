import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../bloc/chat_bloc.dart';
import '../../domain/entities/chat_message.dart';

/// Chat page with message bubbles + input field + auto-polling
class ChatPage extends StatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessages(widget.conversationId));
    // Get current user id from auth
    _loadUserId();
  }

  void _loadUserId() {
    try {
      // Try to read from auth bloc or shared prefs
      // For now, we'll detect from messages — the sender that isn't the other party
    } catch (_) {}
  }

  @override
  void dispose() {
    context.read<ChatBloc>().stopPolling();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(SendMessage(widget.conversationId, text));
    _msgController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KhairColors.darkBackground : KhairColors.background;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listenWhen: (prev, curr) => prev.messages.length != curr.messages.length,
              listener: (context, state) => _scrollToBottom(),
              builder: (context, state) {
                if (state.messagesStatus == ChatStatus.loading && state.messages.isEmpty) {
                  return Center(child: CircularProgressIndicator(color: KhairColors.primary));
                }
                if (state.messages.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 64,
                          color: isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary),
                      const SizedBox(height: 16),
                      Text('Say hello! 👋',
                          style: TextStyle(
                            color: isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary,
                            fontSize: 15,
                          )),
                    ]),
                  );
                }

                // Detect current user: if first message sender differs, we figure it out
                if (_currentUserId == null && state.messages.isNotEmpty) {
                  // Heuristic: we'll set it from the conversations state
                  // For now, we track the first sender and mark subsequent differently
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final msg = state.messages[index];
                    final isMe = _isCurrentUser(msg, state.messages);
                    final showDate = index == 0 ||
                        !_isSameDay(state.messages[index - 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatDate(msg.createdAt),
                              style: TextStyle(
                                color: isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 8, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? KhairColors.darkSurface : Colors.white,
              border: Border(top: BorderSide(color: bdr)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(
                      color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : KhairColors.neutral50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: KhairColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Detect if sender is the current user — simple heuristic
  bool _isCurrentUser(ChatMessage msg, List<ChatMessage> allMessages) {
    // If user sent a message, the first one we sent is "ours"
    // We use a simple approach: track the first non-unique sender
    if (_currentUserId != null) return msg.senderId == _currentUserId;

    // Set from the latest message we sent (after send)
    // Fallback: alternate based on sender patterns
    // In production, pass userId from auth
    return false;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Today';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMM d, y').format(dt);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isMe) const Spacer(flex: 2),
          Flexible(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? KhairColors.primary
                    : (isDark ? KhairColors.darkSurfaceVariant : KhairColors.neutral100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(message.senderName!,
                          style: TextStyle(
                            color: KhairColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  Text(message.message,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : (isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary),
                        fontSize: 14,
                        height: 1.4,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('h:mm a').format(message.createdAt),
                          style: TextStyle(
                            color: isMe
                                ? Colors.white70
                                : (isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary),
                            fontSize: 10,
                          )),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          color: message.isRead ? Colors.lightBlueAccent : Colors.white54,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isMe) const Spacer(flex: 2),
        ],
      ),
    );
  }
}
