class LessonRequest {
  final String id;
  final String studentId;
  final String sheikhId;
  final String message;
  final DateTime? preferredTime;
  final String status;
  final String? studentName;
  final String? sheikhName;
  final DateTime createdAt;
  final DateTime updatedAt;

  LessonRequest({
    required this.id,
    required this.studentId,
    required this.sheikhId,
    required this.message,
    this.preferredTime,
    required this.status,
    this.studentName,
    this.sheikhName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonRequest.fromJson(Map<String, dynamic> json) {
    return LessonRequest(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      sheikhId: json['sheikh_id'] ?? '',
      message: json['message'] ?? '',
      preferredTime: json['preferred_time'] != null
          ? DateTime.tryParse(json['preferred_time'])
          : null,
      status: json['status'] ?? 'pending',
      studentName: json['student_name'],
      sheikhName: json['sheikh_name'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}
