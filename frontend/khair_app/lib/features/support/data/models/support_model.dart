class SupportTicket {
  final String id;
  final String userId;
  final String category;
  final String subject;
  final String status;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'],
      subject: json['subject'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class SupportAttachment {
  final String id;
  final String fileUrl;
  final String mimeType;

  SupportAttachment({
    required this.id,
    required this.fileUrl,
    required this.mimeType,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: json['id'],
      fileUrl: json['file_url'],
      mimeType: json['mime_type'],
    );
  }
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderType; // user, ai, support_agent, system
  final String body;
  final DateTime createdAt;
  final String? senderName;
  final SupportAttachment? attachment;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.attachment,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'],
      ticketId: json['ticket_id'],
      senderType: json['sender_type'],
      body: json['body'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      senderName: json['sender_name'],
      attachment: json['attachment'] != null ? SupportAttachment.fromJson(json['attachment']) : null,
    );
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromSystem => senderType == 'system';
}
