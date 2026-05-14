import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../data/services/meow_ai_service.dart';
import '../data/services/motivation_service.dart';
import '../views/calendar/CalendarScreen.dart';
import '../views/onboarding/user_goal_screen.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class AIPlannerScreen extends StatefulWidget {
  const AIPlannerScreen({super.key});

  @override
  State<AIPlannerScreen> createState() => _AIPlannerScreenState();
}

class _AIPlannerScreenState extends State<AIPlannerScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _focus  = FocusNode();

  List<_Msg> _msgs    = [];
  bool       _loading = false;
  File?      _pendingImage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Gửi tin nhắn động viên khi mở app
    MotivationService.sendInAppMotivation();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final h = await MeowAIService.loadHistory();
    setState(() {
      _msgs = h
          .map((m) => _Msg(
                isUser: m['role'] != 'ai',
                text:   m['content']!,
              ))
          .toList();
    });
    _jump();
  }

  // ── Gửi tin nhắn (có hoặc không có ảnh) ──────────────
  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    final hasImage = _pendingImage != null;
    if ((text.isEmpty && !hasImage) || _loading) return;

    final imageFile = _pendingImage;
    setState(() {
      _msgs.add(_Msg(
        isUser: true,
        text: text.isEmpty ? '📷 [Hình ảnh]' : text,
        imageFile: imageFile,
      ));
      _loading = true;
      _pendingImage = null;
    });
    _ctrl.clear();
    _focus.requestFocus();
    _jump();

    MeowResponse res;
    if (imageFile != null) {
      res = await MeowAIService.askMeowWithImage(text, imageFile);
    } else {
      res = await MeowAIService.askMeow(text);
    }

    setState(() {
      _msgs.add(_Msg(isUser: false, text: res.text));
      _loading = false;
    });

    // Xử lý study plan
    if (res.studyPlan != null) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) _confirmStudyPlan(res.studyPlan!);
    } else if (res.calendarEvent != null) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) _confirmCalendarWithConflictCheck(res.calendarEvent!);
    }
    _jump();
  }

  // ── Chọn ảnh từ gallery hoặc camera ──────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked != null) {
        setState(() => _pendingImage = File(picked.path));
      }
    } catch (_) {}
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Chọn ảnh', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ImageSourceBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Thư viện',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                _ImageSourceBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _jump() {
    Future.delayed(const Duration(milliseconds: 280), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Xác nhận thêm sự kiện (có kiểm tra xung đột) ─────
  Future<void> _confirmCalendarWithConflictCheck(CalendarEventData ev) async {
    final conflicts = await MeowAIService.checkConflicts(ev);
    if (!mounted) return;

    if (conflicts.isNotEmpty) {
      _showConflictDialog(ev, conflicts.first);
    } else {
      _confirmCalendar(ev);
    }
  }

  // ── Dialog xử lý xung đột lịch ────────────────────────
  void _showConflictDialog(
    CalendarEventData newEvent,
    Map<String, dynamic> existingEvent,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConflictDialog(
        newEvent: newEvent,
        existingEvent: existingEvent,
        onOption1: () async {
          // Sự kiện mới ưu tiên → lùi sự kiện cũ 1 tiếng
          Navigator.pop(context);
          final existDate = (existingEvent['date'] as dynamic).toDate() as DateTime;
          final parts = (existingEvent['time'] as String? ?? '08:00').split(':');
          final existTime = TimeComponents(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
          final newHour = (existTime.hour + 1) % 24;
          final rescheduled = TimeComponents(hour: newHour, minute: existTime.minute);
          await MeowAIService.rescheduleEvent(
            existingEvent['id'] as String,
            existDate,
            rescheduled,
          );
          final ok = await MeowAIService.saveEventToCalendar(newEvent);
          if (mounted) {
            _showSnack(ok
                ? '✅ Đã thêm sự kiện mới, lùi sự kiện cũ 1 tiếng'
                : '❌ Lỗi khi lưu sự kiện');
          }
        },
        onOption2: () async {
          // Sự kiện cũ ưu tiên → lùi sự kiện mới 1 tiếng
          Navigator.pop(context);
          final newHour = (newEvent.time.hour + 1) % 24;
          final rescheduledNew = CalendarEventData(
            title: newEvent.title,
            description: newEvent.description,
            date: newEvent.date,
            time: TimeComponents(hour: newHour, minute: newEvent.time.minute),
          );
          final ok = await MeowAIService.saveEventToCalendar(rescheduledNew);
          if (mounted) {
            _showSnack(ok
                ? '✅ Đã thêm sự kiện mới lúc ${rescheduledNew.time}'
                : '❌ Lỗi khi lưu sự kiện');
          }
        },
        onOption3: () async {
          // Xóa sự kiện cũ, thêm sự kiện mới
          Navigator.pop(context);
          await MeowAIService.deleteEvent(existingEvent['id'] as String);
          final ok = await MeowAIService.saveEventToCalendar(newEvent);
          if (mounted) {
            _showSnack(ok
                ? '✅ Đã xóa sự kiện cũ và thêm sự kiện mới'
                : '❌ Lỗi khi lưu sự kiện');
          }
        },
      ),
    );
  }

  void _confirmCalendar(CalendarEventData ev) {
    final date = DateFormat('dd/MM/yyyy').format(ev.date);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarSheet(
        event: ev,
        dateStr: date,
        onConfirm: () async {
          final ok = await MeowAIService.saveEventToCalendar(ev);
          if (mounted) {
            _showSnack(ok
                ? '✅ Đã thêm "${ev.title}" vào lịch'
                : '❌ Không thể lưu sự kiện',
                isSuccess: ok);
          }
        },
      ),
    );
  }

  // ── Xác nhận kế hoạch học tập ─────────────────────────
  void _confirmStudyPlan(StudyPlanData plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StudyPlanSheet(
        plan: plan,
        onConfirm: () async {
          // Lưu kế hoạch
          await MeowAIService.saveStudyPlan(plan);
          // Lưu tất cả sự kiện vào calendar
          final saved = await MeowAIService.saveMultipleEventsToCalendar(
            plan.calendarEvents,
          );
          if (mounted) {
            _showSnack('✅ Đã lưu kế hoạch và $saved sự kiện vào lịch!');
          }
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? const Color(0xFF06D6A0) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Clear ──────────────────────────────────────────────
  void _askClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa cuộc trò chuyện?'),
        content: const Text('Lịch sử chat sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await MeowAIService.clearHistory();
              setState(() => _msgs.clear());
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F8),
      appBar: _AppBar(
        onCalendar: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
        onGoal: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const UserGoalScreen())),
        onClear: _msgs.isEmpty ? null : _askClear,
      ),
      body: Column(
        children: [
          Expanded(
            child: _msgs.isEmpty
                ? _Welcome(onChip: _send)
                : _ChatList(msgs: _msgs, loading: _loading, scroll: _scroll),
          ),
          // Preview ảnh đang chờ gửi
          if (_pendingImage != null)
            _ImagePreview(
              file: _pendingImage!,
              onRemove: () => setState(() => _pendingImage = null),
            ),
          _InputBar(
            ctrl: _ctrl,
            focus: _focus,
            loading: _loading,
            onSend: _send,
            onPickImage: _showImagePicker,
          ),
        ],
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onCalendar;
  final VoidCallback onGoal;
  final VoidCallback? onClear;
  const _AppBar({required this.onCalendar, required this.onGoal, this.onClear});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('😺', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meow AI',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF06D6A0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Online', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.flag_outlined, color: Color(0xFF667eea), size: 22),
          onPressed: onGoal,
          tooltip: 'Mục tiêu học tập',
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF667eea), size: 22),
          onPressed: onCalendar,
          tooltip: 'Xem lịch',
        ),
        if (onClear != null)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 22),
            onPressed: onClear,
            tooltip: 'Xóa lịch sử',
          ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }
}

// ─── Chat list ────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final List<_Msg>   msgs;
  final bool         loading;
  final ScrollController scroll;
  const _ChatList({
    required this.msgs,
    required this.loading,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      itemCount: msgs.length + (loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == msgs.length) return const _TypingIndicator();
        return _BubbleRow(msg: msgs[i]);
      },
    );
  }
}

// ─── Bubble ───────────────────────────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  final _Msg msg;
  const _BubbleRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('😺', style: TextStyle(fontSize: 15))),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Hiển thị ảnh nếu có
                if (msg.imageFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      msg.imageFile!,
                      width: 200,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (msg.text.isNotEmpty && msg.text != '📷 [Hình ảnh]')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.70,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF667eea)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(18),
                        topRight:    const Radius.circular(18),
                        bottomLeft:  Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? const Color(0xFF667eea).withOpacity(0.25)
                              : Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('😺', style: TextStyle(fontSize: 15)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(18),
                topRight:    Radius.circular(18),
                bottomLeft:  Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 5),
                _Dot(delay: 180),
                const SizedBox(width: 5),
                _Dot(delay: 360),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _a = Tween(begin: 0.0, end: -5.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _c.repeat(reverse: true); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _a.value),
        child: Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode             focus;
  final bool                  loading;
  final void Function([String?]) onSend;
  final VoidCallback          onPickImage;
  const _InputBar({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  GrammarResult?   _grammarSuggestion;
  TranslateResult? _translateSuggestion;
  bool             _checkingGrammar    = false;
  bool             _checkingTranslate  = false;
  String           _lastCheckedText    = '';

  // Debounce counter — mỗi lần text đổi tăng lên, cancel check cũ
  int _debounceVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.ctrl.text.trim();

    // Ẩn suggestion nếu text thay đổi
    if (_grammarSuggestion != null && text != _grammarSuggestion!.corrected) {
      setState(() => _grammarSuggestion = null);
    }
    if (_translateSuggestion != null && text != _translateSuggestion!.original) {
      setState(() => _translateSuggestion = null);
    }

    final words = text.split(RegExp(r'\s+'));
    final hasEnoughWords = words.length >= 2;
    if (!hasEnoughWords || text == _lastCheckedText) return;

    final looksLikeEnglish    = _isLikelyEnglish(text);
    final looksLikeVietnamese = _isLikelyVietnamese(text);

    if (!looksLikeEnglish && !looksLikeVietnamese) return;

    // Debounce 1.5s
    final version = ++_debounceVersion;
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted || _debounceVersion != version) return;
      final current = widget.ctrl.text.trim();
      if (current != text || current == _lastCheckedText) return;

      _lastCheckedText = current;

      if (looksLikeEnglish && words.length >= 3) {
        // Kiểm tra grammar tiếng Anh
        setState(() { _checkingGrammar = true; _translateSuggestion = null; });
        final result = await MeowAIService.correctGrammar(current);
        if (!mounted || _debounceVersion != version) return;
        setState(() {
          _grammarSuggestion = result;
          _checkingGrammar   = false;
        });
      } else if (looksLikeVietnamese) {
        // Dịch tiếng Việt → Anh
        setState(() { _checkingTranslate = true; _grammarSuggestion = null; });
        final result = await MeowAIService.translateViToEn(current);
        if (!mounted || _debounceVersion != version) return;
        setState(() {
          _translateSuggestion = result;
          _checkingTranslate   = false;
        });
      }
    });
  }

  /// Heuristic: kiểm tra xem text có khả năng là tiếng Anh không
  bool _isLikelyEnglish(String text) {
    if (text.isEmpty) return false;
    final total = text.length;
    final ascii = text.runes.where((r) => r < 128).length;
    return ascii / total > 0.75;
  }

  /// Heuristic: kiểm tra xem text có khả năng là tiếng Việt không
  /// (có dấu tiếng Việt hoặc từ phổ biến)
  bool _isLikelyVietnamese(String text) {
    if (text.isEmpty) return false;
    // Các ký tự đặc trưng tiếng Việt
    final viChars = RegExp(r'[àáâãèéêìíòóôõùúýăđơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]', caseSensitive: false);
    final viCount = viChars.allMatches(text).length;
    return viCount >= 1;
  }

  void _applyCorrection() {
    if (_grammarSuggestion == null) return;
    widget.ctrl.text = _grammarSuggestion!.corrected;
    widget.ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.ctrl.text.length),
    );
    setState(() {
      _lastCheckedText   = _grammarSuggestion!.corrected;
      _grammarSuggestion = null;
    });
  }

  void _applyTranslation() {
    if (_translateSuggestion == null) return;
    widget.ctrl.text = _translateSuggestion!.translation;
    widget.ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.ctrl.text.length),
    );
    setState(() {
      _lastCheckedText     = _translateSuggestion!.translation;
      _translateSuggestion = null;
    });
  }

  // ── Quick Phrases bottom sheet ─────────────────────────
  void _showQuickPhrases() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QuickPhrasesSheet(
        onSelect: (phrase) {
          Navigator.pop(context);
          widget.ctrl.text = phrase;
          widget.ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: phrase.length),
          );
          widget.focus.requestFocus();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Grammar suggestion banner ──────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: _grammarSuggestion != null
              ? _GrammarBanner(
                  result: _grammarSuggestion!,
                  onApply: _applyCorrection,
                  onDismiss: () => setState(() => _grammarSuggestion = null),
                )
              : _translateSuggestion != null
                  ? _TranslateBanner(
                      result: _translateSuggestion!,
                      onApply: _applyTranslation,
                      onDismiss: () => setState(() => _translateSuggestion = null),
                    )
                  : (_checkingGrammar || _checkingTranslate)
                      ? _GrammarCheckingIndicator(
                          isDark: isDark,
                          label: _checkingTranslate
                              ? 'Meow đang dịch...'
                              : 'Meow đang kiểm tra grammar...',
                        )
                      : const SizedBox.shrink(),
        ),

        // ── Input row ──────────────────────────────────────
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Quick phrases button
              GestureDetector(
                onTap: _showQuickPhrases,
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('💬', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              // Image picker button
              GestureDetector(
                onTap: widget.onPickImage,
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.image_outlined, color: Color(0xFF667eea), size: 20),
                ),
              ),
              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: widget.ctrl,
                    focusNode: widget.focus,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhắn tin với Meow...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.ctrl,
                builder: (_, val, __) {
                  final active = val.text.trim().isNotEmpty && !widget.loading;
                  return GestureDetector(
                    onTap: active ? () => widget.onSend() : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF667eea) : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [BoxShadow(
                                color: const Color(0xFF667eea).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )]
                            : [],
                      ),
                      child: widget.loading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: active ? Colors.white : Colors.grey.shade400,
                              size: 20,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Grammar Suggestion Banner ────────────────────────────────────────────────

class _GrammarBanner extends StatelessWidget {
  final GrammarResult result;
  final VoidCallback  onApply;
  final VoidCallback  onDismiss;

  const _GrammarBanner({
    required this.result,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF06D6A0).withValues(alpha: 0.12),
            const Color(0xFF667eea).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: const Color(0xFF06D6A0).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('✏️', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.corrected,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (result.explanation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    result.explanation,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Apply button
                    GestureDetector(
                      onTap: onApply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06D6A0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✅ Áp dụng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss button
                    GestureDetector(
                      onTap: onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Bỏ qua',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Close X
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _GrammarCheckingIndicator extends StatelessWidget {
  final bool isDark;
  final String label;
  const _GrammarCheckingIndicator({
    required this.isDark,
    this.label = 'Meow đang kiểm tra grammar...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ─── Translate Banner ─────────────────────────────────────────────────────────

class _TranslateBanner extends StatelessWidget {
  final TranslateResult result;
  final VoidCallback    onApply;
  final VoidCallback    onDismiss;

  const _TranslateBanner({
    required this.result,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withValues(alpha: 0.12),
            const Color(0xFFFF8C69).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('🌐', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.translation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (result.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    result.note,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onApply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🌐 Dùng bản dịch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Bỏ qua',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Phrases Sheet ──────────────────────────────────────────────────────

class _QuickPhrasesSheet extends StatefulWidget {
  final ValueChanged<String> onSelect;
  const _QuickPhrasesSheet({required this.onSelect});

  @override
  State<_QuickPhrasesSheet> createState() => _QuickPhrasesSheetState();
}

class _QuickPhrasesSheetState extends State<_QuickPhrasesSheet> {
  int _selectedCategory = 0;

  static const _categories = [
    _PhraseCategory(
      emoji: '📚',
      label: 'Học tập',
      phrases: [
        'Help me make a study plan for IELTS',
        'What does this word mean?',
        'Can you explain this grammar rule?',
        'Give me 10 vocabulary words about travel',
        'How do I improve my writing skills?',
        'What are common IELTS writing mistakes?',
      ],
    ),
    _PhraseCategory(
      emoji: '💬',
      label: 'Giao tiếp',
      phrases: [
        'How do I introduce myself in English?',
        'What are polite ways to disagree?',
        'How do I make small talk?',
        'Teach me phrases for job interviews',
        'How do I apologize formally in English?',
        'What are common email phrases?',
      ],
    ),
    _PhraseCategory(
      emoji: '✍️',
      label: 'Viết',
      phrases: [
        'Check my English sentence:',
        'Help me write a formal email',
        'How do I start an essay?',
        'What are good transition words?',
        'Correct this paragraph:',
        'Give me synonyms for "important"',
      ],
    ),
    _PhraseCategory(
      emoji: '🌐',
      label: 'Dịch',
      phrases: [
        'Dịch câu này sang tiếng Anh:',
        'Translate this to Vietnamese:',
        'Cách nói "xin lỗi" trang trọng trong tiếng Anh?',
        'Dịch đoạn văn này:',
        'Cách diễn đạt ý này bằng tiếng Anh:',
        '"Tôi muốn học tiếng Anh" dịch thế nào?',
      ],
    ),
    _PhraseCategory(
      emoji: '🎯',
      label: 'Mục tiêu',
      phrases: [
        'Create a 3-month IELTS study plan',
        'I want to reach B2 level in 6 months',
        'Set a reminder to study every day at 8am',
        'What should I focus on for IELTS speaking?',
        'How many words do I need for IELTS 7.0?',
        'Make a weekly study schedule for me',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = _categories[_selectedCategory];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                const Text(
                  'Câu mẫu nhanh',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  'Chọn để điền vào ô chat',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Category tabs
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = _selectedCategory == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF667eea)
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                            color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Phrases list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: category.phrases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final phrase = category.phrases[i];
                return GestureDetector(
                  onTap: () => widget.onSelect(phrase),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            phrase,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF333333),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.north_west_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PhraseCategory {
  final String emoji;
  final String label;
  final List<String> phrases;
  const _PhraseCategory({
    required this.emoji,
    required this.label,
    required this.phrases,
  });
}

// ─── Welcome screen ───────────────────────────────────────────────────────────

class _Welcome extends StatelessWidget {
  final void Function([String?]) onChip;
  const _Welcome({required this.onChip});

  static const _chips = [
    ('📅', 'Lập kế hoạch học hôm nay'),
    ('🗓️', 'Tạo lộ trình học IELTS 6 tháng'),
    ('💡', 'Gợi ý cách học từ vựng hiệu quả'),
    ('🎯', 'Lộ trình đạt IELTS 7.0'),
    ('📷', 'Đọc lịch từ ảnh chụp'),
    ('⏰', 'Nhắc nhở học mỗi ngày lúc 8h'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(child: Text('😺', style: TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 20),
          const Text(
            'Xin chào! Mình là Meow',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(
            'Trợ lý AI học tiếng Anh của bạn.\nHỏi mình bất cứ điều gì, hoặc gửi ảnh lịch để mình đọc nhé!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.6),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: Divider(color: Colors.grey.shade200)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Gợi ý', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade200)),
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _chips
                .map((c) => _Chip(emoji: c.$1, label: c.$2, onTap: () => onChip(c.$2)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _Chip({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF444444),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Calendar bottom sheet ────────────────────────────────────────────────────

class _CalendarSheet extends StatelessWidget {
  final CalendarEventData event;
  final String            dateStr;
  final VoidCallback      onConfirm;
  const _CalendarSheet({
    required this.event,
    required this.dateStr,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF667eea), size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thêm vào Lịch',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Event card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    '$dateStr  ${event.time}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ]),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Text('Bỏ qua',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm vào lịch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _Msg {
  final bool   isUser;
  final String text;
  final File?  imageFile;
  const _Msg({required this.isUser, required this.text, this.imageFile});
}

// ─── Image Preview ────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _ImagePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, height: 100, width: 100, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image Source Button ──────────────────────────────────────────────────────

class _ImageSourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImageSourceBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Conflict Dialog ──────────────────────────────────────────────────────────

class _ConflictDialog extends StatelessWidget {
  final CalendarEventData newEvent;
  final Map<String, dynamic> existingEvent;
  final VoidCallback onOption1;
  final VoidCallback onOption2;
  final VoidCallback onOption3;

  const _ConflictDialog({
    required this.newEvent,
    required this.existingEvent,
    required this.onOption1,
    required this.onOption2,
    required this.onOption3,
  });

  @override
  Widget build(BuildContext context) {
    final existTitle = existingEvent['title'] as String? ?? 'Sự kiện cũ';
    final existTime  = existingEvent['time']  as String? ?? '??:??';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Xung đột lịch!',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Hai sự kiện bị trùng thời gian:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // Event cards
            _ConflictEventCard(
              label: 'Sự kiện mới',
              title: newEvent.title,
              time: newEvent.time.toString(),
              color: const Color(0xFF667eea),
            ),
            const SizedBox(height: 8),
            _ConflictEventCard(
              label: 'Sự kiện hiện có',
              title: existTitle,
              time: existTime,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Chọn cách xử lý:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // 3 options
            _ConflictOption(
              number: '1',
              text: 'Ưu tiên sự kiện MỚI → Lùi sự kiện cũ 1 tiếng',
              color: const Color(0xFF667eea),
              onTap: onOption1,
            ),
            const SizedBox(height: 8),
            _ConflictOption(
              number: '2',
              text: 'Ưu tiên sự kiện CŨ → Lùi sự kiện mới 1 tiếng',
              color: Colors.orange,
              onTap: onOption2,
            ),
            const SizedBox(height: 8),
            _ConflictOption(
              number: '3',
              text: 'Xóa sự kiện cũ, giữ sự kiện mới',
              color: Colors.red,
              onTap: onOption3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy bỏ', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictEventCard extends StatelessWidget {
  final String label;
  final String title;
  final String time;
  final Color color;
  const _ConflictEventCard({
    required this.label,
    required this.title,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ConflictOption extends StatelessWidget {
  final String number;
  final String text;
  final Color color;
  final VoidCallback onTap;
  const _ConflictOption({
    required this.number,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ─── Study Plan Sheet ─────────────────────────────────────────────────────────

class _StudyPlanSheet extends StatelessWidget {
  final StudyPlanData plan;
  final VoidCallback  onConfirm;
  const _StudyPlanSheet({required this.plan, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF667eea), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kế hoạch học tập', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(
                      'Mục tiêu: ${plan.targetLevel} · ${plan.hoursPerWeek}h/tuần',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Milestones
          if (plan.milestones.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: plan.milestones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = plan.milestones[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF667eea),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(
                                DateFormat('dd/MM/yyyy').format(m.dueDate),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (plan.calendarEvents.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF667eea), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${plan.calendarEvents.length} sự kiện sẽ được thêm vào lịch',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF667eea), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Lưu kế hoạch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
