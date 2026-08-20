import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

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
  final TextEditingController _catController = TextEditingController();
  final TextEditingController _subjController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _catController.dispose();
    _subjController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.khairSupport, style: KhairTypography.headlineSmall),
        centerTitle: true,
        actions: [
          BlocBuilder<SupportCubit, SupportState>(
            builder: (context, state) {
              if (state is SupportSessionActive && state.ticket.status == 'ai_active') {
                return TextButton(
                  onPressed: () {
                    context.read<SupportCubit>().escalate();
                  },
                  child: Text(AppLocalizations.of(context)!.talkToHuman, style: TextStyle(color: KhairColors.primary)),
                );
              }
              if (state is SupportSessionActive && state.ticket.status != 'resolved') {
                 return TextButton(
                  onPressed: () {
                    context.read<SupportCubit>().resolve();
                  },
                  child: Text(AppLocalizations.of(context)!.resolveTicket, style: TextStyle(color: KhairColors.success)),
                );
              }
              return SizedBox();
            },
          )
        ],
      ),
      body: BlocConsumer<SupportCubit, SupportState>(
        listener: (context, state) {
          if (!mounted) return;
          if (state is SupportSessionActive) {
            _scrollToBottom();
          } else if (state is SupportError) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is SupportLoading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is SupportError) {
            return Center(child: Text(state.error, style: TextStyle(color: Colors.red)));
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
          return SizedBox();
        },
      ),
    );
  }

  Widget _buildStartSession(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(AppLocalizations.of(context)!.howCanWeHelpYou, style: KhairTypography.h3, textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.askKhairAi, style: KhairTypography.bodyLarge, textAlign: TextAlign.center),
          SizedBox(height: 32),
          TextField(
            controller: _catController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.supportCategory,
              hintText: AppLocalizations.of(context)!.supportCategoryHint,
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _subjController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.howCanWeHelp,
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              if (_subjController.text.isNotEmpty) {
                context.read<SupportCubit>().startSession(
                  _catController.text.isEmpty ? 'General' : _catController.text,
                  _subjController.text,
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.startChat, style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    if (status == 'ai_active') {
      return Container(
        color: KhairColors.primarySurface,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: KhairColors.primary, size: 16),
            SizedBox(width: 8),
            Text(context.l10n.youAreChattingWithKhairAi, style: TextStyle(color: KhairColors.primaryDark, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    if (status == 'waiting_for_support') {
      return Container(
        color: KhairColors.warningLight,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.support_agent, color: KhairColors.warningDark, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(context)!.waitingForSupportAgent, style: TextStyle(color: KhairColors.warningDark)),
            ),
          ],
        ),
      );
    }
    if (status == 'resolved') {
       return Container(
        color: KhairColors.successLight,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: KhairColors.success, size: 16),
            SizedBox(width: 8),
            Text(context.l10n.thisTicketHasBeenResolved, style: TextStyle(color: KhairColors.successDark)),
          ],
        ),
      );
    }
    return SizedBox();
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
            child: Text(msg.body, style: TextStyle(color: KhairColors.neutral600, fontSize: 12)),
          ),
        ),
      );
    }

    final isAi = msg.senderType == 'ai';
    final bgColor = isMe ? KhairColors.primary : (isAi ? KhairColors.primarySurface : KhairColors.neutral100);
    final textColor = isMe ? Colors.white : KhairColors.neutral900;
    
    return Align(
      alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(isMe ? 16 : 0),
            bottomEnd: Radius.circular(isMe ? 0 : 16),
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
                    if (isAi) Icon(Icons.auto_awesome, size: 12, color: KhairColors.primary),
                    if (isAi) SizedBox(width: 4),
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
            SizedBox(height: 4),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), offset: Offset(0, -2), blurRadius: 4),
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
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.attach_file, color: KhairColors.neutral500),
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
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(Icons.send, color: Colors.white, size: 20),
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
