class Conversation {
  final String id;
  final String studentId;
  final String sheikhId;
  final String? lessonRequestId;
  final DateTime createdAt;
  final String otherPartyName;
  final String? otherPartyAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.studentId,
    required this.sheikhId,
    this.lessonRequestId,
    required this.createdAt,
    required this.otherPartyName,
    this.otherPartyAvatar,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      sheikhId: json['sheikh_id'] ?? '',
      lessonRequestId: json['lesson_request_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      otherPartyName: json['other_party_name'] ?? 'Unknown',
      otherPartyAvatar: json['other_party_avatar'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}
