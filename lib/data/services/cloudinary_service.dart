import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_secrets.dart';

/// Cloudinary Upload Service — dùng unsigned upload preset (không cần server)
class CloudinaryService {
  // Lấy config từ AppSecrets (.env) — không hardcode
  static String get _cloudName    => AppSecrets.cloudinaryCloudName;
  static String get _uploadPreset => AppSecrets.cloudinaryUploadPreset;
  static const _folder = 'vocabo/avatars';

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload ảnh avatar, trả về URL công khai
  /// [file] — file ảnh từ image_picker
  /// [uid]  — Firebase UID để đặt tên file (public_id)
  static Future<String> uploadAvatar(File file, String uid) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder']        = _folder;
    request.fields['public_id']     = uid; // dùng uid làm tên file

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      // Trả về secure_url (HTTPS)
      return json['secure_url'] as String;
    } else {
      final err = jsonDecode(body);
      throw Exception('Cloudinary error: ${err['error']?['message'] ?? body}');
    }
  }

  /// Xóa ảnh cũ (optional, cần API key — bỏ qua nếu dùng overwrite)
  /// Với overwrite=true, upload mới sẽ tự ghi đè file cũ cùng public_id
}
