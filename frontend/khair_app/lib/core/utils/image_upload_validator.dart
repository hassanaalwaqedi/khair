import 'dart:typed_data';
import 'dart:ui' as ui;

const maxMobileImageUploadBytes = 5 * 1024 * 1024;

enum ImageUploadIssue {
  empty,
  tooLarge,
  unsupportedType,
  invalidImage,
}

/// Validates the actual bytes, not only the filename supplied by a picker.
/// The backend repeats this validation; this check prevents avoidable uploads
/// and gives the user immediate, field-level feedback.
Future<ImageUploadIssue?> inspectImageUpload({
  required String filename,
  required Uint8List bytes,
  int maxBytes = maxMobileImageUploadBytes,
}) async {
  if (bytes.isEmpty) return ImageUploadIssue.empty;
  if (bytes.length > maxBytes) return ImageUploadIssue.tooLarge;

  final extension = filename.split('.').last.toLowerCase();
  if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
    return ImageUploadIssue.unsupportedType;
  }

  if (!_matchesImageSignature(bytes, extension)) {
    return ImageUploadIssue.unsupportedType;
  }

  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (width < 160 || height < 160 || width > 8000 || height > 8000) {
      return ImageUploadIssue.invalidImage;
    }
  } catch (_) {
    return ImageUploadIssue.invalidImage;
  }
  return null;
}

bool _matchesImageSignature(Uint8List bytes, String extension) {
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return bytes.length >= 3 &&
          bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    case 'png':
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      return bytes.length >= signature.length &&
          List<int>.generate(signature.length, (i) => bytes[i])
              .asMap()
              .entries
              .every((entry) => entry.value == signature[entry.key]);
    case 'webp':
      return bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    default:
      return false;
  }
}

String? validateImageUpload({
  required String filename,
  required int byteLength,
  int maxBytes = maxMobileImageUploadBytes,
}) {
  if (byteLength <= 0) {
    return 'The selected image is empty. Choose another photo.';
  }
  if (byteLength > maxBytes) {
    final limitMb = maxBytes ~/ (1024 * 1024);
    return 'Choose an image smaller than $limitMb MB.';
  }

  final extension = filename.split('.').last.toLowerCase();
  if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
    return 'Use a JPG, PNG, or WebP image.';
  }
  return null;
}
