import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AppSecrets — Quản lý tập trung tất cả API keys & secrets
///
/// CÁCH DÙNG:
/// 1. Tạo file `.env` ở root project (đã có trong .gitignore)
/// 2. Điền các key vào `.env` theo mẫu `.env.example`
/// 3. Gọi `AppSecrets.load()` trong `main()` trước khi dùng
///
/// KHÔNG BAO GIỜ hardcode key trực tiếp trong source code!
class AppSecrets {
  AppSecrets._(); // prevent instantiation

  static bool _loaded = false;

  /// Gọi một lần trong main() trước runApp()
  static Future<void> load() async {
    if (_loaded) return;
    await dotenv.load(fileName: '.env');
    _loaded = true;
  }

  // ── Groq AI ───────────────────────────────────────────
  static String get groqApiKey {
    final key = dotenv.env['GROQ_API_KEY'] ?? '';
    assert(key.isNotEmpty, '⚠️  GROQ_API_KEY chưa được cấu hình trong .env');
    return key;
  }

  // ── Pixabay ───────────────────────────────────────────
  static String get pixabayApiKey =>
      dotenv.env['PIXABAY_API_KEY'] ?? '';

  // ── Cloudinary ────────────────────────────────────────
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'daxudlxgt';

  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'vocabo_avatars';

  // ── Google Sign-In ────────────────────────────────────
  static String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';

  // ── Firebase (optional override) ─────────────────────
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? 'vocabofinalapp';

  // ── Debug flag ────────────────────────────────────────
  static bool get isDebug =>
      (dotenv.env['DEBUG'] ?? 'false').toLowerCase() == 'true';
}
