import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/utils/image_upload_validator.dart';

void main() {
  test('uses the backend-compatible 5 MB image limit', () {
    final bytes = Uint8List(5 * 1024 * 1024 + 1);

    expect(
      validateImageUpload(
        filename: 'profile.jpg',
        byteLength: bytes.length,
      ),
      contains('5 MB'),
    );
  });

  test('rejects unsupported image extensions before upload', () async {
    final issue = await inspectImageUpload(
      filename: 'profile.gif',
      bytes: Uint8List.fromList([71, 73, 70, 56]),
    );

    expect(issue, ImageUploadIssue.unsupportedType);
  });

  test('rejects a file whose bytes do not match its extension', () async {
    final issue = await inspectImageUpload(
      filename: 'profile.png',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(issue, ImageUploadIssue.unsupportedType);
  });
}
