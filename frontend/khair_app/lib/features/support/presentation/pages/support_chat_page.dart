import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khair_app/core/theme/khair_theme.dart';

import '../bloc/support_cubit.dart';
import '../../data/models/support_model.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khair Support', style: KhairTypography.headlineSmall),
        centerTitle: true,
        actions: [
          BlocBuilder<SupportCubit, SupportState>(
            builder: (context, state) {
              if (state is SupportSessionActive && state.ticket.status == 'ai_active') {
                return TextButton(
                  onPressed: () {
                    context.read<SupportCubit>().escalate();
                  },
                  child: const Text('Talk to Human', style: TextStyle(color: KhairColors.primary)),
                );
              }
              if (state is SupportSessionActive && state.ticket.status != 'resolved') {
                 return TextButton(
                  onPressed: () {
                    context.read<SupportCubit>().resolve();
                  },
                  child: const Text('Resolve', style: TextStyle(color: KhairColors.success)),
                );
              }
              return const SizedBox();
            },
          )
        ],
      ),
      body: BlocConsumer<SupportCubit, SupportState>(
        listener: (context, state) {
          if (state is SupportSessionActive) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          if (state is SupportLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SupportError) {
            return Center(child: Text(state.error, style: const TextStyle(color: Colors.red)));
          }
          if (state is SupportInitial) {
            return _buildStartSession(context);
          }
          if (state is SupportSessionActive) {
            return Column(
              children: [
                _buildStatusBanner(state.ticket.status),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final msg = state.messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),
                _buildInputArea(context, state.ticket.status, state.isLoading),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildStartSession(BuildContext context) {
    final catController = TextEditingController();
    final subjController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('How can we help you?', style: KhairTypography.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Ask Khair AI or connect with our support team.', style: KhairTypography.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextField(
            controller: catController,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'e.g., Payment, Account, General',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: subjController,
            decoration: const InputDecoration(
              labelText: 'How can we help?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              if (subjController.text.isNotEmpty) {
                context.read<SupportCubit>().startSession(
                  catController.text.isEmpty ? 'General' : catController.text,
                  subjController.text,
                );
              }
            },
            child: const Text('Start Chat', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    if (status == 'ai_active') {
      return Container(
        color: KhairColors.primarySurface,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: const [
            Icon(Icons.auto_awesome, color: KhairColors.primary, size: 16),
            SizedBox(width: 8),
            Text('You are chatting with Khair AI', style: TextStyle(color: KhairColors.primaryDark, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    if (status == 'waiting_for_support') {
      return Container(
        color: KhairColors.warningLight,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: const [
            Icon(Icons.hourglass_empty, color: KhairColors.warning, size: 16),
            SizedBox(width: 8),
            Text('Waiting for an available support agent...', style: TextStyle(color: KhairColors.warningDark)),
          ],
        ),
      );
    }
    if (status == 'resolved') {
       return Container(
        color: KhairColors.successLight,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: const [
            Icon(Icons.check_circle, color: KhairColors.success, size: 16),
            SizedBox(width: 8),
            Text('This ticket has been resolved.', style: TextStyle(color: KhairColors.successDark)),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildMessageBubble(SupportMessage msg) {
    final isMe = msg.isFromUser;
    final isSystem = msg.isFromSystem;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: KhairColors.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(msg.body, style: const TextStyle(color: KhairColors.neutral600, fontSize: 12)),
          ),
        ),
      );
    }

    final isAi = msg.senderType == 'ai';
    final bgColor = isMe ? KhairColors.primary : (isAi ? KhairColors.primarySurface : KhairColors.neutral100);
    final textColor = isMe ? Colors.white : KhairColors.neutral900;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAi) const Icon(Icons.auto_awesome, size: 12, color: KhairColors.primary),
                    if (isAi) const SizedBox(width: 4),
                    Text(
                      isAi ? 'Khair AI' : (msg.senderName ?? 'Support Agent'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isAi ? KhairColors.primaryDark : KhairColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
            if (msg.attachment != null && msg.attachment!.mimeType.startsWith('image/'))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg.attachment!.fileUrl,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Text(msg.body, style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              DateFormat.jm().format(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : KhairColors.neutral500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, String status, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 4),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: status == 'resolved' ? 'Type to reopen...' : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: KhairColors.neutral100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    context.read<SupportCubit>().sendMessage(val.trim());
                    _messageController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.attach_file, color: KhairColors.neutral500),
              onPressed: isLoading ? null : () async {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null && context.mounted) {
                  context.read<SupportCubit>().uploadAttachment(image.path);
                }
              },
            ),
            CircleAvatar(
              backgroundColor: KhairColors.primary,
              child: IconButton(
                icon: isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: isLoading ? null : () {
                  final text = _messageController.text.trim();
                  if (text.isNotEmpty) {
                    context.read<SupportCubit>().sendMessage(text);
                    _messageController.clear();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
