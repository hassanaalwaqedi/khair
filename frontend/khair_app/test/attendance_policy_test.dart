import 'package:flutter_test/flutter_test.dart';

import 'package:khair_app/features/events/domain/entities/attendance_policy.dart';

void main() {
  group('AttendancePolicy', () {
    test('normalizes legacy values to stable policies', () {
      expect(AttendancePolicy.normalize(null), AttendancePolicy.everyone);
      expect(AttendancePolicy.normalize('mixed'), AttendancePolicy.everyone);
      expect(
        AttendancePolicy.normalize('female_only'),
        AttendancePolicy.womenOnly,
      );
      expect(
        AttendancePolicy.normalize('male_only'),
        AttendancePolicy.menOnly,
      );
    });

    test('maps stable policies back for legacy API compatibility', () {
      expect(
        AttendancePolicy.legacyGenderRestriction(
          AttendancePolicy.everyone,
        ),
        'mixed',
      );
      expect(
        AttendancePolicy.legacyGenderRestriction(
          AttendancePolicy.womenOnly,
        ),
        'female_only',
      );
      expect(
        AttendancePolicy.legacyGenderRestriction(
          AttendancePolicy.menOnly,
        ),
        'male_only',
      );
    });
  });
}
