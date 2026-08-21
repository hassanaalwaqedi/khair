class AttendancePolicy {
  static const everyone = 'EVERYONE';
  static const womenOnly = 'WOMEN_ONLY';
  static const menOnly = 'MEN_ONLY';

  static String normalize(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'FEMALE_ONLY':
      case 'WOMEN_ONLY':
      case 'WOMEN':
      case 'FEMALE':
        return womenOnly;
      case 'MALE_ONLY':
      case 'MEN_ONLY':
      case 'MEN':
      case 'MALE':
        return menOnly;
      default:
        return everyone;
    }
  }

  static String legacyGenderRestriction(String? value) {
    switch (normalize(value)) {
      case womenOnly:
        return 'female_only';
      case menOnly:
        return 'male_only';
      default:
        return 'mixed';
    }
  }
}
