class SupportTicket {
  final String id;
  final String userId;
  final String category;
  final String subject;
  final String status;
  final String language;
  final String? contextType;
  final String? contextId;
  final String? aiSummary;
  final String? assignedToName;
  final DateTime createdAt;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.status,
    required this.language,
    required this.createdAt,
    this.contextType,
    this.contextId,
    this.aiSummary,
    this.assignedToName,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      category: json['category']?.toString() ?? 'general',
      subject: json['subject']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ai_active',
      language: json['language']?.toString() ?? 'en',
      contextType: json['context_type']?.toString(),
      contextId: json['context_id']?.toString(),
      aiSummary: json['ai_summary']?.toString(),
      assignedToName: json['assigned_to_name']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }

  bool get isAiActive => status == 'ai_active';
  bool get isWaitingForAgent => status == 'waiting_for_agent';
  bool get isHumanActive => status == 'human_active';
  bool get isResolved => status == 'resolved' || status == 'closed';

  SupportTicket copyWith({String? status}) => SupportTicket(
        id: id,
        userId: userId,
        category: category,
        subject: subject,
        status: status ?? this.status,
        language: language,
        contextType: contextType,
        contextId: contextId,
        aiSummary: aiSummary,
        assignedToName: assignedToName,
        createdAt: createdAt,
      );
}

class SupportAttachment {
  final String id;
  final String fileUrl;
  final String mimeType;
  final int? sizeBytes;

  const SupportAttachment({
    required this.id,
    required this.fileUrl,
    required this.mimeType,
    this.sizeBytes,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: json['id'].toString(),
      fileUrl: json['file_url'].toString(),
      mimeType: json['mime_type'].toString(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
    );
  }
}

class SupportAction {
  final String type;
  final String label;

  const SupportAction({required this.type, required this.label});

  factory SupportAction.fromJson(Map<String, dynamic> json) => SupportAction(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

class SupportQuickAction extends SupportAction {
  const SupportQuickAction({required super.type, required super.label});

  factory SupportQuickAction.fromJson(Map<String, dynamic> json) =>
      SupportQuickAction(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderType; // user, ai, support_agent, system
  final String body;
  final DateTime createdAt;
  final String? senderName;
  final SupportAttachment? attachment;
  final Map<String, dynamic> metadata;
  final bool isPending;
  final bool isFailed;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.attachment,
    this.metadata = const {},
    this.isPending = false,
    this.isFailed = false,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return SupportMessage(
      id: json['id'].toString(),
      ticketId: json['ticket_id'].toString(),
      senderType: json['sender_type']?.toString() ?? 'system',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
      senderName: json['sender_name']?.toString(),
      attachment: json['attachment'] is Map<String, dynamic>
          ? SupportAttachment.fromJson(
              json['attachment'] as Map<String, dynamic>)
          : null,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const {},
    );
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromSystem => senderType == 'system';
  bool get isFromAi => senderType == 'ai';
  bool get isFromAgent => senderType == 'support_agent';

  List<SupportAction> get actions =>
      _actions('actions', SupportAction.fromJson);
  List<SupportQuickAction> get quickActions =>
      _actions('quick_actions', SupportQuickAction.fromJson);

  List<T> _actions<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final value = metadata[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => fromJson(Map<String, dynamic>.from(entry)))
        .where((action) {
      if (action is SupportAction) return action.type.isNotEmpty;
      return true;
    }).toList();
  }

  SupportMessage copyWith({bool? isPending, bool? isFailed}) => SupportMessage(
        id: id,
        ticketId: ticketId,
        senderType: senderType,
        body: body,
        createdAt: createdAt,
        senderName: senderName,
        attachment: attachment,
        metadata: metadata,
        isPending: isPending ?? this.isPending,
        isFailed: isFailed ?? this.isFailed,
      );
}

class SupportConversation {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  final bool created;

  const SupportConversation({
    required this.ticket,
    required this.messages,
    required this.created,
  });
}
