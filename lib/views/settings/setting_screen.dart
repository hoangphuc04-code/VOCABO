// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'ThemeProvider.dart';
import '../../routes/app_routes.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/currency_service.dart';
import '../profile/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingScreen — Cài đặt đầy đủ
// ─────────────────────────────────────────────────────────────────────────────

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  // User data
  String _displayName = '';
  String _photoURL    = '';
  String _level       = 'A1';
  String _targetLevel = 'B2';
  int    _streak      = 0;
  int    _wordsLearned = 0;
  int    _dailyGoal   = 30;
  String _fashionGender = 'female';
  String _motivationStyle = 'fun';

  // Settings
  bool _notification = true;
  bool _isLoading    = true;
  bool _isUploadingPhoto = false;

  bool get _isGoogleUser =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_user == null) { setState(() => _isLoading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(_user.uid).get();
      final d = doc.data() ?? {};
      setState(() {
        _displayName    = d['displayName'] ?? d['name'] ?? _user.displayName ?? '';
        _photoURL       = d['photoURL']    ?? d['photoUrl'] ?? _user.photoURL ?? '';
        _level          = d['level']       ?? d['currentLevel'] ?? 'A1';
        _targetLevel    = d['targetLevel'] ?? 'B2';
        _streak         = (d['streak']     ?? 0).toInt();
        _wordsLearned   = (d['wordsLearned'] ?? 0).toInt();
        _dailyGoal      = (d['dailyGoalMinutes'] ?? 30).toInt();
        _fashionGender  = d['fashionGender'] ?? 'female';
        _motivationStyle = d['motivationStyle'] ?? 'fun';
        _notification   = d['notification'] ?? true;
      });
    } catch (_) {
      _displayName = _user.displayName ?? '';
      _photoURL    = _user.photoURL    ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveField(Map<String, dynamic> data) async {
    if (_user == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(_user.uid)
        .set(data, SetOptions(merge: true));
  }

  // ── Avatar upload ──────────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await CloudinaryService.uploadAvatar(
          File(picked.path), _user!.uid);
      await _user.updatePhotoURL(url);
      await _saveField({'photoURL': url});
      setState(() => _photoURL = url);
    } catch (e) {
      if (mounted) _showSnack('Lỗi tải ảnh: $e', isError: true);
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Rename ─────────────────────────────────────────────────────────────────
  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đổi tên hiển thị'),
        content: TextField(
          controller: ctrl,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: 'Nhập tên mới...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await _user!.updateDisplayName(name);
              await _saveField({
                'displayName': name,
                'searchName': name.toLowerCase(),
              });
              setState(() => _displayName = name);
              _showSnack('Đã cập nhật tên');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // ── Change password ────────────────────────────────────────────────────────
  void _showChangePasswordSheet() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool obscOld = true, obscNew = true, obscConf = true;
    bool loading = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 20),
              const Text('🔒 Đổi mật khẩu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Nhập mật khẩu hiện tại rồi chọn mật khẩu mới.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 20),
              _pwField(ctx, oldCtrl, 'Mật khẩu hiện tại', obscOld,
                  () => setBS(() => obscOld = !obscOld)),
              const SizedBox(height: 12),
              _pwField(ctx, newCtrl, 'Mật khẩu mới', obscNew,
                  () => setBS(() => obscNew = !obscNew)),
              const SizedBox(height: 12),
              _pwField(ctx, confCtrl, 'Xác nhận mật khẩu mới', obscConf,
                  () => setBS(() => obscConf = !obscConf)),
              if (errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: loading ? null : () async {
                    if (newCtrl.text != confCtrl.text) {
                      setBS(() => errorMsg = 'Mật khẩu không khớp');
                      return;
                    }
                    if (newCtrl.text.length < 6) {
                      setBS(() => errorMsg = 'Mật khẩu phải ít nhất 6 ký tự');
                      return;
                    }
                    setBS(() { loading = true; errorMsg = null; });
                    try {
                      final cred = EmailAuthProvider.credential(
                        email: _user!.email!,
                        password: oldCtrl.text,
                      );
                      await _user.reauthenticateWithCredential(cred);
                      await _user.updatePassword(newCtrl.text);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _showSnack('Đổi mật khẩu thành công ✅');
                      }
                    } on FirebaseAuthException catch (e) {
                      setBS(() {
                        loading = false;
                        errorMsg = e.code == 'wrong-password'
                            ? 'Mật khẩu hiện tại không đúng'
                            : e.message ?? 'Lỗi không xác định';
                      });
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pwField(BuildContext ctx, TextEditingController ctrl,
      String label, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
      ),
    );
  }

  // ── Delete account ─────────────────────────────────────────────────────────
  void _showDeleteAccountDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ Xóa tài khoản', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hành động này không thể hoàn tác. Tất cả dữ liệu học tập, pet, farm sẽ bị xóa vĩnh viễn.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (!_isGoogleUser) ...[
              const Text('Nhập mật khẩu để xác nhận:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Mật khẩu',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount(ctrl.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    try {
      if (!_isGoogleUser && password.isNotEmpty) {
        final cred = EmailAuthProvider.credential(
          email: _user!.email!, password: password);
        await _user.reauthenticateWithCredential(cred);
      } else if (_isGoogleUser) {
        await GoogleSignIn.instance.initialize();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final auth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          idToken: auth.idToken);
        await _user!.reauthenticateWithCredential(cred);
      }
      // Xóa Firestore data
      final uid = _user!.uid;
      final db = FirebaseFirestore.instance;
      await Future.wait([
        db.collection('users').doc(uid).delete(),
        db.collection('houses').doc(uid).delete(),
        db.collection('farms').doc(uid).delete(),
      ]);
      await _user.delete();
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Lỗi xóa tài khoản', isError: true);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try { await GoogleSignIn.instance.signOut(); } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  void _goToProfile() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade400 : const Color(0xFF667eea),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader(cs, isDark)),

          // ── Stats bar ───────────────────────────────────
          SliverToBoxAdapter(child: _buildStatsBar(cs)),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // ── HỌC TẬP ─────────────────────────────
                _SectionLabel(label: '📚 Học tập'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _ArrowTile(
                    icon: Icons.flag_rounded, iconBg: const Color(0xFF43A047),
                    title: 'Mục tiêu hàng ngày',
                    subtitle: '$_dailyGoal phút/ngày',
                    onTap: _showDailyGoalSheet,
                  ),
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.school_rounded, iconBg: const Color(0xFF1E88E5),
                    title: 'Trình độ hiện tại',
                    subtitle: 'Lv.$_level → Mục tiêu: $_targetLevel',
                    onTap: _showLevelSheet,
                  ),
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.psychology_rounded, iconBg: const Color(0xFF8E24AA),
                    title: 'Phong cách học',
                    subtitle: _motivationLabel(_motivationStyle),
                    onTap: _showMotivationSheet,
                  ),
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.bar_chart_rounded, iconBg: const Color(0xFF00897B),
                    title: 'Thống kê học tập',
                    onTap: _goToProfile,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── NHÂN VẬT ────────────────────────────
                _SectionLabel(label: '🎮 Nhân vật'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _GenderTile(
                    current: _fashionGender,
                    onChanged: (g) async {
                      setState(() => _fashionGender = g);
                      await _saveField({'fashionGender': g});
                    },
                  ),
                ]),

                const SizedBox(height: 20),

                // ── GIAO DIỆN ───────────────────────────
                _SectionLabel(label: '🎨 Giao diện'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    iconBg: isDark ? const Color(0xFF667eea) : Colors.amber,
                    title: 'Chế độ tối',
                    value: isDark,
                    onChanged: (v) => context.read<ThemeProvider>().setDark(v),
                  ),
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.language_rounded, iconBg: Colors.teal,
                    title: 'Ngôn ngữ',
                    subtitle: 'Tiếng Việt',
                    onTap: _showLanguageDialog,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── THÔNG BÁO ───────────────────────────
                _SectionLabel(label: '🔔 Thông báo'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.notifications_rounded, iconBg: Colors.orange,
                    title: 'Thông báo học tập',
                    value: _notification,
                    onChanged: (v) async {
                      setState(() => _notification = v);
                      await _saveField({'notification': v});
                    },
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.local_fire_department_rounded, iconBg: Colors.deepOrange,
                    title: 'Nhắc nhở streak',
                    value: _notification,
                    onChanged: (v) async {
                      setState(() => _notification = v);
                      await _saveField({'streakReminder': v});
                    },
                  ),
                ]),

                const SizedBox(height: 20),

                // ── TÀI KHOẢN ───────────────────────────
                _SectionLabel(label: '👤 Tài khoản'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _ArrowTile(
                    icon: Icons.person_rounded, iconBg: const Color(0xFF667eea),
                    title: 'Chỉnh sửa hồ sơ',
                    onTap: _goToProfile,
                  ),
                  if (!_isGoogleUser) ...[
                    _Divider(),
                    _ArrowTile(
                      icon: Icons.lock_rounded, iconBg: Colors.purple,
                      title: 'Đổi mật khẩu',
                      onTap: _showChangePasswordSheet,
                    ),
                  ],
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.sync_rounded, iconBg: const Color(0xFF26A69A),
                    title: 'Đồng bộ dữ liệu',
                    onTap: () async {
                      await _loadSettings();
                      _showSnack('Đồng bộ thành công ✅');
                    },
                  ),
                ]),

                const SizedBox(height: 20),

                // ── HỖ TRỢ ──────────────────────────────
                _SectionLabel(label: '💬 Hỗ trợ'),
                const SizedBox(height: 8),
                _SettingsCard(children: [
                  _ArrowTile(
                    icon: Icons.help_outline_rounded, iconBg: Colors.blue,
                    title: 'Trợ giúp & Hỗ trợ',
                    onTap: _showHelpDialog,
                  ),
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.star_rounded, iconBg: Colors.amber,
                    title: 'Đánh giá ứng dụng',
                    onTap: () => _showSnack('Cảm ơn bạn đã ủng hộ! ⭐'),
                  ),
                  _Divider(),
                  _ArrowTile(
                    icon: Icons.info_outline_rounded, iconBg: Colors.grey,
                    title: 'Về ứng dụng',
                    subtitle: 'Vocabo v1.0.0',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Vocabo',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 Vocabo Team',
                    ),
                  ),
                ]),

                const SizedBox(height: 32),

                // ── ĐĂNG XUẤT ───────────────────────────
                _LogoutButton(onTap: _logout),

                const SizedBox(height: 16),

                // ── XÓA TÀI KHOẢN ───────────────────────
                Center(
                  child: TextButton(
                    onPressed: _showDeleteAccountDialog,
                    child: const Text(
                      'Xóa tài khoản',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with avatar ─────────────────────────────────────────────────────
  Widget _buildHeader(ColorScheme cs, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2D1B69), const Color(0xFF11998E)]
              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  const Text('⚙️ Cài đặt',
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Currency display
                  StreamBuilder<Map<String, dynamic>>(
                    stream: CurrencyService.currencyStream(),
                    builder: (context, snap) {
                      final d = snap.data ?? {};
                      final hearts   = (d['hearts']   ?? 5).toInt();
                      final diamonds = (d['diamonds'] ?? 0).toInt();
                      return Row(children: [
                        _CurrencyPill(icon: '❤️', value: hearts),
                        const SizedBox(width: 6),
                        _CurrencyPill(icon: '💎', value: diamonds),
                      ]);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Avatar + name
              Row(
                children: [
                  // Avatar with upload button
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                            )],
                          ),
                          child: ClipOval(
                            child: _isUploadingPhoto
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : (_photoURL.isNotEmpty
                                    ? Image.network(_photoURL, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                            Icons.person_rounded, color: Colors.white, size: 36))
                                    : const Icon(Icons.person_rounded, color: Colors.white, size: 36)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Color(0xFF667eea)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _displayName.isNotEmpty ? _displayName : 'Người dùng',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _showRenameDialog,
                              child: const Icon(Icons.edit_rounded,
                                  color: Colors.white70, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          _LevelBadge(level: _level),
                          const SizedBox(width: 6),
                          _ProviderBadge(isGoogle: _isGoogleUser),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(
        children: [
          _StatItem(emoji: '🔥', value: '$_streak', label: 'Streak'),
          _StatDivider(),
          _StatItem(emoji: '📖', value: '$_wordsLearned', label: 'Từ vựng'),
          _StatDivider(),
          _StatItem(emoji: '⏱️', value: '$_dailyGoal\'', label: 'Mục tiêu'),
          _StatDivider(),
          _StatItem(emoji: '🎯', value: _targetLevel, label: 'Mục tiêu'),
        ],
      ),
    );
  }

  // ── Dialogs / Sheets ───────────────────────────────────────────────────────

  void _showDailyGoalSheet() {
    int selected = _dailyGoal;
    const goals = [5, 10, 15, 20, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('⏱️ Mục tiêu hàng ngày',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: goals.map((g) {
                  final sel = selected == g;
                  return GestureDetector(
                    onTap: () => setBS(() => selected = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF667eea) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? const Color(0xFF667eea) : Colors.grey.shade300),
                      ),
                      child: Text('$g phút',
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _dailyGoal = selected);
                    await _saveField({'dailyGoalMinutes': selected});
                    _showSnack('Đã cập nhật mục tiêu: $selected phút/ngày');
                  },
                  child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelSheet() {
    String selCurrent = _level;
    String selTarget  = _targetLevel;
    const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('🎓 Trình độ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Trình độ hiện tại:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: levels.map((l) {
                  final sel = selCurrent == l;
                  return GestureDetector(
                    onTap: () => setBS(() => selCurrent = l),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF1E88E5) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(l, style: TextStyle(
                        color: sel ? Colors.white : Colors.black87,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Mục tiêu:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8,
                children: levels.map((l) {
                  final sel = selTarget == l;
                  return GestureDetector(
                    onTap: () => setBS(() => selTarget = l),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF43A047) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(l, style: TextStyle(
                        color: sel ? Colors.white : Colors.black87,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() { _level = selCurrent; _targetLevel = selTarget; });
                    await _saveField({'level': selCurrent, 'currentLevel': selCurrent, 'targetLevel': selTarget});
                    _showSnack('Đã cập nhật trình độ');
                  },
                  child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMotivationSheet() {
    const styles = {
      'gentle': ('🌸', 'Nhẹ nhàng', 'Khuyến khích, không áp lực'),
      'strict': ('💪', 'Nghiêm túc', 'Kỷ luật cao, nhắc nhở thường xuyên'),
      'fun':    ('🎉', 'Vui vẻ',    'Gamification, phần thưởng nhiều'),
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('🧠 Phong cách học',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...styles.entries.map((e) {
              final (emoji, title, desc) = e.value;
              final sel = _motivationStyle == e.key;
              return GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _motivationStyle = e.key);
                  await _saveField({'motivationStyle': e.key});
                  _showSnack('Đã chọn phong cách: $title');
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF667eea).withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? const Color(0xFF667eea) : Colors.grey.shade200,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    )),
                    if (sel) const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF667eea)),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🌐 Ngôn ngữ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇻🇳', style: TextStyle(fontSize: 24)),
              title: const Text('Tiếng Việt'),
              trailing: const Icon(Icons.check_rounded, color: Color(0xFF667eea)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              onTap: () {
                Navigator.pop(context);
                _showSnack('English coming soon');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💬 Trợ giúp & Hỗ trợ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HelpItem(icon: '📧', title: 'Email hỗ trợ', subtitle: 'support@vocabo.app'),
            _HelpItem(icon: '📖', title: 'Hướng dẫn sử dụng', subtitle: 'Xem tài liệu online'),
            _HelpItem(icon: '🐛', title: 'Báo lỗi', subtitle: 'Gửi báo cáo lỗi'),
            _HelpItem(icon: '💡', title: 'Góp ý tính năng', subtitle: 'Đề xuất cải tiến'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  String _motivationLabel(String style) {
    switch (style) {
      case 'gentle': return '🌸 Nhẹ nhàng';
      case 'strict': return '💪 Nghiêm túc';
      default:       return '🎉 Vui vẻ';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 0),
    child: Text(label, style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    )),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 6, offset: const Offset(0, 2),
      )],
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1, indent: 56, endIndent: 0,
    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
  );
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.iconBg,
      required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      _IconBox(icon: icon, color: iconBg),
      const SizedBox(width: 14),
      Expanded(child: Text(title, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500))),
      Switch(value: value, onChanged: onChanged,
          activeColor: const Color(0xFF667eea)),
    ]),
  );
}

class _ArrowTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ArrowTile({required this.icon, required this.iconBg,
      required this.title, required this.onTap, this.subtitle});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          _IconBox(icon: icon, color: iconBg),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 14,
              color: cs.onSurface.withValues(alpha: 0.3)),
        ]),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: Colors.white, size: 18),
  );
}

class _StatItem extends StatelessWidget {
  final String emoji, value, label;
  const _StatItem({required this.emoji, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]),
  );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 36,
    color: Colors.grey.withValues(alpha: 0.2),
  );
}

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('Lv.$level', style: const TextStyle(
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

class _ProviderBadge extends StatelessWidget {
  final bool isGoogle;
  const _ProviderBadge({required this.isGoogle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(isGoogle ? Icons.g_mobiledata : Icons.email_outlined,
          size: 12, color: Colors.white),
      const SizedBox(width: 3),
      Text(isGoogle ? 'Google' : 'Email',
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    ]),
  );
}

class _CurrencyPill extends StatelessWidget {
  final String icon;
  final int value;
  const _CurrencyPill({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 3),
      Text('$value', style: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _GenderTile extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _GenderTile({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      _IconBox(icon: Icons.person_pin_rounded, color: const Color(0xFFE91E63)),
      const SizedBox(width: 14),
      const Expanded(child: Text('Nhân vật chibi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
      // Toggle female/male
      Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _GenderBtn(label: '👧 Nữ', selected: current == 'female',
              onTap: () => onChanged('female')),
          _GenderBtn(label: '👦 Nam', selected: current == 'male',
              onTap: () => onChanged('male')),
        ]),
      ),
    ]),
  );
}

class _GenderBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF667eea) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: selected ? Colors.white : Colors.grey.shade600,
      )),
    ),
  );
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text('Đăng xuất',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade500,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _HelpItem extends StatelessWidget {
  final String icon, title, subtitle;
  const _HelpItem({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    ]),
  );
}
