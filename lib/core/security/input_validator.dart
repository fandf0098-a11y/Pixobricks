/// InputValidator — centralised validation & sanitisation helpers.
/// Prevents XSS, injection, and malformed data from reaching the backend.
class InputValidator {
  InputValidator._();

  // ── Email ────────────────────────────────────────────────────────────────
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    if (value.length > 254) return 'Email is too long';
    return null;
  }

  // ── Password ─────────────────────────────────────────────────────────────
  static String? validatePassword(String? value, {bool isSignUp = false}) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (isSignUp) {
      if (value.length < 8) return 'Password must be at least 8 characters';
      if (!value.contains(RegExp(r'[A-Z]'))) {
        return 'Include at least one uppercase letter';
      }
      if (!value.contains(RegExp(r'[0-9]'))) {
        return 'Include at least one number';
      }
    } else {
      if (value.length < 6) return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  // ── Display name ─────────────────────────────────────────────────────────
  static final _dangerousCharsRegex = RegExp(r'''[<>&"'`]''');

  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    if (value.length > 50) return 'Name must be 50 characters or fewer';
    if (_dangerousCharsRegex.hasMatch(value)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  // ── Generic text ─────────────────────────────────────────────────────────
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? validateMaxLength(String? value, int max, String fieldName) {
    if (value != null && value.length > max) {
      return '$fieldName must be $max characters or fewer';
    }
    return null;
  }

  // ── Sanitisation ─────────────────────────────────────────────────────────

  /// Strip leading/trailing whitespace and collapse internal whitespace.
  static String sanitizeText(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Remove HTML/script tags to prevent stored XSS.
  static String sanitizeHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .trim();
  }

  /// Validate that a string is a valid UUID v4.
  static bool isValidUuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  /// Validate URL is http/https only (prevents javascript: injection).
  static bool isValidUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    try {
      final uri = Uri.parse(value);
      return uri.scheme == 'https' || uri.scheme == 'http';
    } catch (_) {
      return false;
    }
  }
}