import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../bloc/chat_bloc.dart';

/// Shows all conversations for the current user
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(const LoadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KhairColors.darkBackground : KhairColors.background;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state.conversationsStatus == ChatStatus.loading) {
            return Center(child: CircularProgressIndicator(color: KhairColors.primary));
          }
          if (state.conversationsStatus == ChatStatus.failure) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline_rounded, size: 48, color: KhairColors.error),
                const SizedBox(height: 12),
                const Text('Failed to load conversations'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.read<ChatBloc>().add(const LoadConversations()),
                  child: const Text('Retry'),
                ),
              ]),
            );
          }
          if (state.conversations.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 64, color: KhairColors.neutral400),
                const SizedBox(height: 16),
                Text('No conversations yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary)),
                const SizedBox(height: 8),
                Text('Request a lesson from a sheikh to start chatting',
                    style: TextStyle(fontSize: 13, color: ts)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.school_rounded, size: 18),
                  label: const Text('Browse Sheikhs'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KhairColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ]),
            );
          }

          return RefreshIndicator(
            color: KhairColors.primary,
            onRefresh: () async {
              context.read<ChatBloc>().add(const LoadConversations());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color: isDark ? KhairColors.darkBorder : KhairColors.border,
              ),
              itemBuilder: (context, index) {
                final conv = state.conversations[index];
                final hasUnread = conv.unreadCount > 0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: KhairColors.primarySurface,
                    backgroundImage: conv.otherPartyAvatar != null
                        ? NetworkImage(conv.otherPartyAvatar!)
                        : null,
                    child: conv.otherPartyAvatar == null
                        ? Text(conv.otherPartyName[0].toUpperCase(),
                            style: TextStyle(color: KhairColors.primary, fontWeight: FontWeight.w700))
                        : null,
                  ),
                  title: Text(conv.otherPartyName,
                      style: TextStyle(
                        color: tp,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      )),
                  subtitle: conv.lastMessage != null
                      ? Text(conv.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? tp : ts,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ))
                      : Text('Start chatting...', style: TextStyle(color: ts, fontSize: 13)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (conv.lastMessageAt != null)
                        Text(_formatTime(conv.lastMessageAt!),
                            style: TextStyle(color: ts, fontSize: 11)),
                      if (hasUnread) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: KhairColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${conv.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => context.go('/conversations/${conv.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return DateFormat('h:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }
}
