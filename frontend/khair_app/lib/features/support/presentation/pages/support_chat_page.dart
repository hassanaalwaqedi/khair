import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../data/models/support_model.dart';
import '../bloc/support_cubit.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({
    super.key,
    this.initialTicketId,
    this.contextType,
    this.contextId,
  });

  final String? initialTicketId;
  final String? contextType;
  final String? contextId;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openConversation());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openConversation() {
    if (!mounted) return;
    context.read<SupportCubit>().openConversation(
          Localizations.localeOf(context).languageCode,
          initialTicketId: widget.initialTicketId,
          contextType: widget.contextType,
          contextId: widget.contextId,
        );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = _SupportCopy.of(Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: KhairColors.neutral50,
      appBar: AppBar(
        titleSpacing: 0,
        title: BlocBuilder<SupportCubit, SupportState>(
          builder: (context, state) => _AppBarIdentity(
            copy: copy,
            ticket: state is SupportSessionActive ? state.ticket : null,
          ),
        ),
        actions: [
          IconButton(
            tooltip: copy.previousConversations,
            onPressed: _showHistory,
            icon: const Icon(Icons.history_outlined),
          ),
          PopupMenuButton<_SupportMenuAction>(
            tooltip: copy.moreOptions,
            onSelected: (action) {
              if (action == _SupportMenuAction.escalate) {
                context.read<SupportCubit>().escalate();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SupportMenuAction.escalate,
                child: Row(
                  children: [
                    const Icon(Icons.support_agent_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(copy.talkToSupport),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<SupportCubit, SupportState>(
        listener: (context, state) {
          if (state is SupportSessionActive) {
            _scrollToBottom();
            if (state.transientError != null) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(copy.errorFor(state.transientError!))),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is SupportLoading || state is SupportInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SupportError) {
            return _SupportUnavailable(
              copy: copy,
              onRetry: _openConversation,
              onEscalate: _openConversation,
            );
          }
          final active = state as SupportSessionActive;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                children: [
                  _ConversationStatus(ticket: active.ticket, copy: copy),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      itemCount: active.messages.length +
                          (active.isSending && active.ticket.isAiActive
                              ? 1
                              : 0) +
                          1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _WelcomeIdentity(copy: copy);
                        }
                        final messageIndex = index - 1;
                        if (messageIndex >= active.messages.length) {
                          return _ThinkingIndicator(copy: copy);
                        }
                        final message = active.messages[messageIndex];
                        return _MessageBubble(
                          message: message,
                          copy: copy,
                          onRetry: () => context
                              .read<SupportCubit>()
                              .retryMessage(message),
                          onAction: _handleAction,
                          onQuickAction: (action) {
                            context
                                .read<SupportCubit>()
                                .sendMessage(action.label);
                          },
                        );
                      },
                    ),
                  ),
                  if (_showResolutionPrompt(active))
                    _ResolutionPrompt(
                      copy: copy,
                      onResolved: () => context.read<SupportCubit>().resolve(),
                      onEscalate: () => context.read<SupportCubit>().escalate(),
                    ),
                  _Composer(
                    controller: _messageController,
                    copy: copy,
                    enabled: !active.isSending,
                    resolved: active.ticket.isResolved,
                    onSend: _send,
                    onAttachment: _pickAttachment,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _showResolutionPrompt(SupportSessionActive state) {
    if (state.ticket.isResolved || state.ticket.isWaitingForAgent) return false;
    return state.messages.where((message) => message.isFromAi).length >= 2;
  }

  void _send() {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    context.read<SupportCubit>().sendMessage(body);
    _messageController.clear();
  }

  Future<void> _pickAttachment() async {
    final copy = _SupportCopy.of(Localizations.localeOf(context).languageCode);
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(copy.imageLimit)),
      );
      return;
    }
    final allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
    final dot = file.name.lastIndexOf('.');
    final extension = dot < 0 ? '' : file.name.substring(dot).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(copy.imageType)),
      );
      return;
    }
    context.read<SupportCubit>().uploadAttachment(bytes, file.name);
  }

  void _handleAction(SupportAction action) {
    switch (action.type) {
      case 'open_my_events':
        context.push('/my-events');
      case 'view_organizer_application':
        context.push('/organizer/apply');
      case 'open_notification_settings':
        context.push('/notifications');
      case 'talk_to_support':
        context.read<SupportCubit>().escalate();
    }
  }

  Future<void> _showHistory() async {
    final copy = _SupportCopy.of(Localizations.localeOf(context).languageCode);
    final cubit = context.read<SupportCubit>();
    final tickets = await cubit.getHistory();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .58,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(copy.previousConversations,
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              Expanded(
                child: tickets.isEmpty
                    ? Center(child: Text(copy.noConversations))
                    : ListView.separated(
                        itemCount: tickets.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final ticket = tickets[index];
                          return ListTile(
                            leading: Icon(ticket.isResolved
                                ? Icons.check_circle_outline
                                : Icons.forum_outlined),
                            title: Text(
                              ticket.subject.isEmpty
                                  ? copy.supportConversation
                                  : ticket.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(copy.statusLabel(ticket.status)),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              cubit.loadTicket(ticket);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SupportMenuAction { escalate }

class _AppBarIdentity extends StatelessWidget {
  const _AppBarIdentity({required this.copy, this.ticket});

  final _SupportCopy copy;
  final SupportTicket? ticket;

  @override
  Widget build(BuildContext context) {
    final isHumanConversation = ticket?.isHumanActive ?? false;
    return Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: isHumanConversation
                ? KhairColors.successLight
                : KhairColors.primarySurface,
            child: Icon(
              isHumanConversation ? Icons.support_agent : Icons.auto_awesome,
              color:
                  isHumanConversation ? KhairColors.success : KhairColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(copy.supportTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(isHumanConversation ? copy.supportTeam : copy.aiAssistant,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KhairColors.neutral600,
                      )),
            ],
          ),
        ],
      );
  }
}

class _ConversationStatus extends StatelessWidget {
  const _ConversationStatus({required this.ticket, required this.copy});

  final SupportTicket ticket;
  final _SupportCopy copy;

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = switch (ticket.status) {
      'waiting_for_agent' => (
          Icons.schedule_outlined,
          KhairColors.warningDark,
          copy.waitingForAgent,
        ),
      'human_active' => (
          Icons.support_agent,
          KhairColors.success,
          copy.humanJoined,
        ),
      'resolved' || 'closed' => (
          Icons.check_circle_outline,
          KhairColors.success,
          copy.resolved,
        ),
      _ => (Icons.auto_awesome, KhairColors.primary, copy.chattingWithAi),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _WelcomeIdentity extends StatelessWidget {
  const _WelcomeIdentity({required this.copy});

  final _SupportCopy copy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: KhairColors.primarySurface,
              child: Icon(Icons.auto_awesome, color: KhairColors.primary),
            ),
            const SizedBox(height: 8),
            Text('Khair AI', style: Theme.of(context).textTheme.titleMedium),
            Text(copy.aiAssistant,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: KhairColors.neutral600)),
          ],
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.copy,
    required this.onRetry,
    required this.onAction,
    required this.onQuickAction,
  });

  final SupportMessage message;
  final _SupportCopy copy;
  final VoidCallback onRetry;
  final ValueChanged<SupportAction> onAction;
  final ValueChanged<SupportQuickAction> onQuickAction;

  @override
  Widget build(BuildContext context) {
    if (message.isFromSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: KhairColors.neutral100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(message.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      );
    }

    final isUser = message.isFromUser;
    final isAi = message.isFromAi;
    final maxWidth = MediaQuery.sizeOf(context).width > 760
        ? 590.0
        : MediaQuery.sizeOf(context).width * .79;
    final background = isUser
        ? KhairColors.primary
        : isAi
            ? KhairColors.primarySurface
            : Colors.white;
    final foreground = isUser ? Colors.white : KhairColors.neutral900;
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(
            color: isUser ? KhairColors.primary : KhairColors.neutral200,
          ),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(isUser ? 18 : 4),
            bottomEnd: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAi ? Icons.auto_awesome : Icons.support_agent,
                      color: isAi ? KhairColors.primary : KhairColors.success,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAi
                          ? 'Khair AI'
                          : (message.senderName ?? copy.supportTeam),
                      style: TextStyle(
                        fontSize: 12,
                        color: isAi
                            ? KhairColors.primaryDark
                            : KhairColors.successDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (message.attachment != null)
              _AttachmentPreview(message: message, copy: copy),
            if (message.body.isNotEmpty)
              Text(message.body,
                  style: TextStyle(color: foreground, height: 1.35)),
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.actions
                    .map(
                      (action) => OutlinedButton(
                        onPressed: () => onAction(action),
                        child: Text(action.label),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (message.quickActions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.quickActions
                    .map(
                      (action) => ActionChip(
                        label: Text(action.label),
                        onPressed: () => onQuickAction(action),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(message.createdAt),
                  style: TextStyle(
                    color: isUser ? Colors.white70 : KhairColors.neutral500,
                    fontSize: 10,
                  ),
                ),
                if (message.isPending) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: isUser ? Colors.white70 : KhairColors.primary,
                    ),
                  ),
                ],
                if (message.isFailed) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(copy.retry,
                        style: TextStyle(
                            color:
                                isUser ? Colors.white : KhairColors.primary)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.message, required this.copy});

  final SupportMessage message;
  final _SupportCopy copy;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment!;
    if (!attachment.mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(copy.imageAttachment),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          attachment.fileUrl,
          width: 240,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
            width: 220,
            height: 80,
            child: Center(child: Text(copy.imageUnavailable)),
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator({required this.copy});

  final _SupportCopy copy;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: KhairColors.primarySurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: KhairColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Text(copy.aiThinking),
            ],
          ),
        ),
      );
}

class _ResolutionPrompt extends StatelessWidget {
  const _ResolutionPrompt({
    required this.copy,
    required this.onResolved,
    required this.onEscalate,
  });

  final _SupportCopy copy;
  final VoidCallback onResolved;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: KhairColors.neutral200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(copy.didThisSolve,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: onResolved, child: Text(copy.yes)),
            TextButton(onPressed: onEscalate, child: Text(copy.no)),
          ],
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.copy,
    required this.enabled,
    required this.resolved,
    required this.onSend,
    required this.onAttachment,
  });

  final TextEditingController controller;
  final _SupportCopy copy;
  final bool enabled;
  final bool resolved;
  final VoidCallback onSend;
  final VoidCallback onAttachment;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: KhairColors.neutral200)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: copy.addImage,
                onPressed: enabled ? onAttachment : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: resolved ? copy.reopenHint : copy.messageHint,
                    filled: true,
                    fillColor: KhairColors.neutral100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: copy.send,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                      backgroundColor: KhairColors.primary),
                  onPressed: enabled ? onSend : null,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SupportUnavailable extends StatelessWidget {
  const _SupportUnavailable({
    required this.copy,
    required this.onRetry,
    required this.onEscalate,
  });

  final _SupportCopy copy;
  final VoidCallback onRetry;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_chat_unread_outlined,
                    size: 48, color: KhairColors.primary),
                const SizedBox(height: 16),
                Text(copy.aiUnavailable,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 18),
                FilledButton(onPressed: onRetry, child: Text(copy.tryAgain)),
                TextButton(
                    onPressed: onEscalate, child: Text(copy.talkToSupport)),
              ],
            ),
          ),
        ),
      );
}

class _SupportCopy {
  const _SupportCopy._(this.language);

  final String language;
  static _SupportCopy of(String language) => _SupportCopy._(
        language.startsWith('ar')
            ? 'ar'
            : language.startsWith('tr')
                ? 'tr'
                : 'en',
      );

  bool get isArabic => language == 'ar';
  String get supportTitle => isArabic
      ? 'دعم خير'
      : language == 'tr'
          ? 'Khair Destek'
          : 'Khair Support';
  String get aiAssistant => isArabic
      ? 'مساعد الذكاء الاصطناعي'
      : language == 'tr'
          ? 'Yapay zekâ destek asistanı'
          : 'AI Support Assistant';
  String get supportTeam => isArabic
      ? 'فريق دعم خير'
      : language == 'tr'
          ? 'Khair Destek Ekibi'
          : 'Khair Support Team';
  String get chattingWithAi => isArabic
      ? 'أنت تتحدث مع ذكاء خير الاصطناعي'
      : language == 'tr'
          ? 'Khair AI ile konuşuyorsunuz'
          : 'You are chatting with Khair AI';
  String get waitingForAgent => isArabic
      ? 'أنت في طابور دعم خير. سنُعلمك عند الرد.'
      : language == 'tr'
          ? 'Khair Destek sırasındasınız. Yanıt geldiğinde haber vereceğiz.'
          : 'You are in the Khair Support queue. We’ll notify you when someone replies.';
  String get humanJoined => isArabic
      ? 'فريق دعم خير متصل الآن'
      : language == 'tr'
          ? 'Khair Destek ekibi sizinle'
          : 'Khair Support is now in this conversation';
  String get resolved => isArabic
      ? 'تم حل هذه المحادثة'
      : language == 'tr'
          ? 'Bu konuşma çözüldü'
          : 'This conversation is resolved';
  String get moreOptions => isArabic
      ? 'خيارات إضافية'
      : language == 'tr'
          ? 'Diğer seçenekler'
          : 'More options';
  String get previousConversations => isArabic
      ? 'المحادثات السابقة'
      : language == 'tr'
          ? 'Önceki konuşmalar'
          : 'Previous conversations';
  String get noConversations => isArabic
      ? 'لا توجد محادثات سابقة'
      : language == 'tr'
          ? 'Önceki konuşma yok'
          : 'No previous conversations';
  String get supportConversation => isArabic
      ? 'محادثة دعم'
      : language == 'tr'
          ? 'Destek konuşması'
          : 'Support conversation';
  String get talkToSupport => isArabic
      ? 'تحدث إلى دعم خير'
      : language == 'tr'
          ? 'Khair Desteğe bağlan'
          : 'Talk to Khair Support';
  String get aiThinking => isArabic
      ? 'ذكاء خير الاصطناعي يفكر...'
      : language == 'tr'
          ? 'Khair AI düşünüyor...'
          : 'Khair AI is thinking...';
  String get didThisSolve => isArabic
      ? 'هل حلّ هذا مشكلتك؟'
      : language == 'tr'
          ? 'Bu sorununuzu çözdü mü?'
          : 'Did this solve your problem?';
  String get yes => isArabic
      ? 'نعم'
      : language == 'tr'
          ? 'Evet'
          : 'Yes';
  String get no => isArabic
      ? 'لا'
      : language == 'tr'
          ? 'Hayır'
          : 'No';
  String get messageHint => isArabic
      ? 'اكتب رسالة إلى خير...'
      : language == 'tr'
          ? 'Khair’a mesaj yazın...'
          : 'Message Khair...';
  String get reopenHint => isArabic
      ? 'اكتب رسالة للمتابعة...'
      : language == 'tr'
          ? 'Devam etmek için mesaj yazın...'
          : 'Send a message to continue...';
  String get send => isArabic
      ? 'إرسال'
      : language == 'tr'
          ? 'Gönder'
          : 'Send';
  String get retry => isArabic
      ? 'إعادة المحاولة'
      : language == 'tr'
          ? 'Tekrar dene'
          : 'Retry';
  String get addImage => isArabic
      ? 'إضافة صورة'
      : language == 'tr'
          ? 'Görsel ekle'
          : 'Add image';
  String get imageLimit => isArabic
      ? 'اختر صورة أصغر من 5 ميجابايت.'
      : language == 'tr'
          ? '5 MB’den küçük bir görsel seçin.'
          : 'Choose an image smaller than 5 MB.';
  String get imageType => isArabic
      ? 'استخدم صورة JPG أو PNG أو WebP.'
      : language == 'tr'
          ? 'JPG, PNG veya WebP görsel seçin.'
          : 'Use a JPG, PNG, or WebP image.';
  String get imageAttachment => isArabic
      ? 'مرفق صورة'
      : language == 'tr'
          ? 'Görsel eki'
          : 'Image attachment';
  String get imageUnavailable => isArabic
      ? 'تعذر تحميل الصورة'
      : language == 'tr'
          ? 'Görsel yüklenemedi'
          : 'Image unavailable';
  String get aiUnavailable => isArabic
      ? 'تواجه خدمة الذكاء الاصطناعي صعوبة الآن. يمكنك المحاولة مرة أخرى أو التواصل مع دعم خير.'
      : language == 'tr'
          ? 'Yapay zekâ şu anda yanıt veremiyor. Tekrar deneyebilir veya Khair Desteğe bağlanabilirsiniz.'
          : 'Khair AI is having trouble responding right now. You can try again or contact Khair Support.';
  String get tryAgain => isArabic
      ? 'حاول مرة أخرى'
      : language == 'tr'
          ? 'Tekrar dene'
          : 'Try again';
  String errorFor(String error) => switch (error) {
        'message_failed' => isArabic
            ? 'تعذر إرسال رسالتك. يمكنك إعادة المحاولة.'
            : language == 'tr'
                ? 'Mesajınız gönderilemedi. Tekrar deneyin.'
                : 'Your message could not be sent. You can retry it.',
        'attachment_failed' => isArabic
            ? 'تعذر رفع الصورة. حاول مرة أخرى.'
            : language == 'tr'
                ? 'Görsel yüklenemedi. Tekrar deneyin.'
                : 'The image could not be uploaded. Try again.',
        'escalation_failed' => isArabic
            ? 'تعذر التواصل مع الدعم الآن. حاول مرة أخرى.'
            : language == 'tr'
                ? 'Desteğe bağlanılamadı. Tekrar deneyin.'
                : 'We could not contact support right now. Try again.',
        _ => isArabic
            ? 'تعذر حل المحادثة الآن.'
            : language == 'tr'
                ? 'Konuşma şu anda çözülemedi.'
                : 'The conversation could not be resolved right now.',
      };
  String statusLabel(String status) => switch (status) {
        'ai_active' => 'Khair AI',
        'waiting_for_agent' => waitingForAgent,
        'human_active' => supportTeam,
        'resolved' || 'closed' => resolved,
        _ => status,
      };
}
