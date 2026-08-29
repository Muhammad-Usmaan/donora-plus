/// Reusable form validators.
///
/// Each returns `null` when valid, or an error message string when invalid.
class Validators {
  const Validators._();

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String field = 'This field']) {
    if (value == null || value.length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }

  static String? bloodType(String? value) {
    const valid = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (value == null || !valid.contains(value)) {
      return 'Select a valid blood type';
    }
    return null;
  }

  /// Compose multiple validators; returns the first error or null.
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final v in validators) {
        final error = v(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
