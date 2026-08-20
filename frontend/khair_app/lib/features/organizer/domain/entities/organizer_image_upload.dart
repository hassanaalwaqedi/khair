import 'dart:typed_data';

enum OrganizerImageUploadStatus {
  empty,
  selected,
  preparing,
  uploading,
  uploaded,
  failed,
}

class OrganizerImageUploadState {
  const OrganizerImageUploadState({
    this.status = OrganizerImageUploadStatus.empty,
    this.localBytes,
    this.filename,
    this.progress = 0,
    this.error,
  });

  final OrganizerImageUploadStatus status;
  final Uint8List? localBytes;
  final String? filename;
  final double progress;
  final String? error;

  bool get isBusy =>
      status == OrganizerImageUploadStatus.preparing ||
      status == OrganizerImageUploadStatus.uploading;

  bool get hasLocalPreview => localBytes != null;

  OrganizerImageUploadState copyWith({
    OrganizerImageUploadStatus? status,
    Uint8List? localBytes,
    String? filename,
    double? progress,
    String? error,
    bool clearError = false,
  }) {
    return OrganizerImageUploadState(
      status: status ?? this.status,
      localBytes: localBytes ?? this.localBytes,
      filename: filename ?? this.filename,
      progress: progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
    );
  }
}
