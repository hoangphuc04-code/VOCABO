import 'package:shared_preferences/shared_preferences.dart';

/// SecurityService — Bảo vệ app khỏi abuse, spam, injection
///
/// Bao gồm:
/// - Input sanitization (chống XSS/injection)
/// - Client-side rate limiting (chống spam API)
/// - Input length validation
class SecurityService {
  SecurityService._();

  // ── Rate Limiting ─────────────────────────────────────
  // Lưu timestamp các request gần nhất theo key
  static final Map<String, List<int>> _requestLog = {};

  /// Kiểm tra rate limit phía client
  /// [key]        — định danh action (vd: 'ai_chat', 'pronunciation')
  /// [maxRequests] — số request tối đa trong [windowSeconds] giây
  /// [windowSeconds] — cửa sổ thời gian (giây)
  static bool checkRateLimit({
    required String key,
    int maxRequests = 10,
    int windowSeconds = 60,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = windowSeconds * 1000;

    _requestLog[key] ??= [];
    // Xóa các request cũ ngoài cửa sổ
    _requestLog[key]!.removeWhere((t) => now - t > windowMs);

    if (_requestLog[key]!.length >= maxRequests) {
      return false; // Rate limit exceeded
    }

    _requestLog[key]!.add(now);
    return true;
  }

  /// Thời gian còn lại (giây) trước khi rate limit reset
  static int rateLimitCooldown({
    required String key,
    int windowSeconds = 60,
  }) {
    final log = _requestLog[key];
    if (log == null || log.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final oldest = log.first;
    final elapsed = (now - oldest) ~/ 1000;
    final remaining = windowSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  // ── Input Sanitization ────────────────────────────────

  /// Làm sạch text input — xóa ký tự nguy hiểm
  static String sanitizeText(String input, {int maxLength = 1000}) {
    if (input.isEmpty) return '';

    var result = input
        // Xóa null bytes
        .replaceAll('\x00', '')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Giới hạn độ dài
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate password strength
  static PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 6) return PasswordStrength.weak;
    if (password.length < 8) return PasswordStrength.fair;

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int score = [hasUpper, hasLower, hasDigit, hasSpecial]
        .where((b) => b)
        .length;

    if (score >= 4 && password.length >= 12) return PasswordStrength.strong;
    if (score >= 3) return PasswordStrength.good;
    return PasswordStrength.fair;
  }

  /// Validate display name
  static String? validateDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Tên không được để trống';
    if (trimmed.length < 2) return 'Tên phải có ít nhất 2 ký tự';
    if (trimmed.length > 50) return 'Tên không được quá 50 ký tự';
    // Chặn ký tự đặc biệt nguy hiểm
    if (RegExp(r'[<>"\x00-\x1F]').hasMatch(trimmed)) {
      return 'Tên chứa ký tự không hợp lệ';
    }
    return null; // valid
  }

  /// Validate topic/deck name
  static String? validateTopicName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Tên chủ đề không được để trống';
    if (trimmed.length > 100) return 'Tên chủ đề không được quá 100 ký tự';
    return null;
  }

  /// Validate word input
  static String? validateWord(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return 'Từ không được để trống';
    if (trimmed.length > 100) return 'Từ không được quá 100 ký tự';
    return null;
  }

  // ── Session Security ──────────────────────────────────

  static const _lastActiveKey = 'last_active_ts';
  static const _sessionTimeoutMinutes = 30 * 24 * 60; // 30 ngày

  /// Cập nhật thời gian hoạt động cuối
  static Future<void> updateLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Kiểm tra session có còn hợp lệ không
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getInt(_lastActiveKey);
    if (lastActive == null) return true; // lần đầu

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastActive;
    final timeoutMs = _sessionTimeoutMinutes * 60 * 1000;
    return elapsed < timeoutMs;
  }

  // ── Content Validation ────────────────────────────────

  /// Kiểm tra URL có hợp lệ và an toàn không
  static bool isSafeUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      // Chỉ cho phép HTTPS
      if (uri.scheme != 'https') return false;
      // Chặn localhost và private IPs
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') return false;
      if (RegExp(r'^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)').hasMatch(host)) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Giới hạn độ dài content trước khi gửi lên AI
  static String truncateForAI(String content, {int maxChars = 3000}) {
    if (content.length <= maxChars) return content;
    return '${content.substring(0, maxChars)}...[truncated]';
  }
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum PasswordStrength {
  weak,   // < 6 chars
  fair,   // 6-7 chars hoặc thiếu đa dạng
  good,   // 8+ chars, 3/4 loại ký tự
  strong, // 12+ chars, đủ 4 loại ký tự
}

extension PasswordStrengthExt on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.weak:   return 'Yếu';
      case PasswordStrength.fair:   return 'Trung bình';
      case PasswordStrength.good:   return 'Tốt';
      case PasswordStrength.strong: return 'Mạnh';
    }
  }

  // ignore: deprecated_member_use
  int get colorValue {
    switch (this) {
      case PasswordStrength.weak:   return 0xFFFF4757;
      case PasswordStrength.fair:   return 0xFFFFB347;
      case PasswordStrength.good:   return 0xFF4CAF50;
      case PasswordStrength.strong: return 0xFF06D6A0;
    }
  }

  double get progress {
    switch (this) {
      case PasswordStrength.weak:   return 0.25;
      case PasswordStrength.fair:   return 0.5;
      case PasswordStrength.good:   return 0.75;
      case PasswordStrength.strong: return 1.0;
    }
  }
}
