const maxMobileImageUploadBytes = 10 * 1024 * 1024;

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
