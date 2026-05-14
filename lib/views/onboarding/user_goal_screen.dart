import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Màn hình thu thập mục tiêu học tập của người dùng
class UserGoalScreen extends StatefulWidget {
  final bool isOnboarding;
  const UserGoalScreen({super.key, this.isOnboarding = false});

  @override
  State<UserGoalScreen> createState() => _UserGoalScreenState();
}

class _UserGoalScreenState extends State<UserGoalScreen> {
  static const _primary = Color(0xFF667eea);
  static const _secondary = Color(0xFF764ba2);

  int _step = 0;

  // Dữ liệu thu thập
  String _currentLevel = 'A1';
  String _targetLevel = 'B2';
  DateTime? _targetDate;
  int _dailyGoalMinutes = 30;
  List<String> _freeTimeSlots = [];
  String _motivationStyle = 'fun';

  bool _saving = false;

  final _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final _levelDescriptions = {
    'A1': 'Mới bắt đầu',
    'A2': 'Cơ bản',
    'B1': 'Trung cấp',
    'B2': 'Trên trung cấp',
    'C1': 'Nâng cao',
    'C2': 'Thành thạo',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primary, _secondary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressBar(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = [
      'Trình độ hiện tại',
      'Mục tiêu của bạn',
      'Thời gian học',
      'Khung giờ rảnh',
      'Phong cách động viên',
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!widget.isOnboarding && _step > 0)
                GestureDetector(
                  onTap: () => setState(() => _step--),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
              const Spacer(),
              if (!widget.isOnboarding)
                TextButton(
                  onPressed: _skip,
                  child: const Text('Bỏ qua', style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '😺 Bước ${_step + 1}/5',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            titles[_step],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_step + 1) / 5,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: [
          _buildCurrentLevelStep(),
          _buildTargetStep(),
          _buildDailyGoalStep(),
          _buildFreeTimeStep(),
          _buildMotivationStyleStep(),
        ][_step],
      ),
    );
  }

  // ── Step 1: Trình độ hiện tại ──────────────────────────
  Widget _buildCurrentLevelStep() {
    return _StepWrapper(
      subtitle: 'Chọn trình độ tiếng Anh hiện tại của bạn',
      onNext: () => setState(() => _step++),
      child: Column(
        children: _levels.map((level) {
          final selected = _currentLevel == level;
          return _LevelCard(
            level: level,
            description: _levelDescriptions[level]!,
            selected: selected,
            onTap: () => setState(() => _currentLevel = level),
          );
        }).toList(),
      ),
    );
  }

  // ── Step 2: Mục tiêu ──────────────────────────────────
  Widget _buildTargetStep() {
    return _StepWrapper(
      subtitle: 'Bạn muốn đạt trình độ nào và khi nào?',
      onNext: () => setState(() => _step++),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trình độ mục tiêu:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _levels
                .where((l) => _levels.indexOf(l) > _levels.indexOf(_currentLevel))
                .map((level) {
              final selected = _targetLevel == level;
              return ChoiceChip(
                label: Text('$level - ${_levelDescriptions[level]}'),
                selected: selected,
                onSelected: (_) => setState(() => _targetLevel = level),
                selectedColor: _primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Ngày mục tiêu:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickTargetDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: _primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: _primary),
                  const SizedBox(width: 12),
                  Text(
                    _targetDate == null
                        ? 'Chọn ngày mục tiêu'
                        : DateFormat('dd/MM/yyyy').format(_targetDate!),
                    style: TextStyle(
                      color: _targetDate == null ? Colors.grey : _primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Thời gian học mỗi ngày ────────────────────
  Widget _buildDailyGoalStep() {
    final options = [10, 15, 20, 30, 45, 60];
    return _StepWrapper(
      subtitle: 'Bạn có thể dành bao nhiêu phút mỗi ngày?',
      onNext: () => setState(() => _step++),
      child: Column(
        children: options.map((min) {
          final selected = _dailyGoalMinutes == min;
          return GestureDetector(
            onTap: () => setState(() => _dailyGoalMinutes = min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? _primary.withOpacity(0.1) : Colors.transparent,
                border: Border.all(
                  color: selected ? _primary : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: selected ? _primary : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$min phút/ngày',
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? _primary : null,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle, color: _primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Step 4: Khung giờ rảnh ────────────────────────────
  Widget _buildFreeTimeStep() {
    final slots = [
      {'key': 'morning', 'label': 'Buổi sáng', 'time': '6:00 - 12:00', 'icon': Icons.wb_sunny_outlined},
      {'key': 'afternoon', 'label': 'Buổi chiều', 'time': '12:00 - 18:00', 'icon': Icons.wb_cloudy_outlined},
      {'key': 'evening', 'label': 'Buổi tối', 'time': '18:00 - 22:00', 'icon': Icons.nights_stay_outlined},
      {'key': 'night', 'label': 'Đêm khuya', 'time': '22:00 - 0:00', 'icon': Icons.bedtime_outlined},
    ];
    return _StepWrapper(
      subtitle: 'Chọn khung giờ bạn thường rảnh (có thể chọn nhiều)',
      onNext: () => setState(() => _step++),
      child: Column(
        children: slots.map((slot) {
          final key = slot['key'] as String;
          final selected = _freeTimeSlots.contains(key);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _freeTimeSlots.remove(key);
                } else {
                  _freeTimeSlots.add(key);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? _primary.withOpacity(0.1) : Colors.transparent,
                border: Border.all(
                  color: selected ? _primary : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(slot['icon'] as IconData, color: selected ? _primary : Colors.grey),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot['label'] as String,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? _primary : null,
                        ),
                      ),
                      Text(
                        slot['time'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle, color: _primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Step 5: Phong cách động viên ──────────────────────
  Widget _buildMotivationStyleStep() {
    final styles = [
      {
        'key': 'fun',
        'label': 'Vui vẻ & Dễ thương 😸',
        'desc': 'Meow sẽ nhắc nhở bằng những tin nhắn dễ thương, hài hước',
        'icon': Icons.emoji_emotions_outlined,
      },
      {
        'key': 'gentle',
        'label': 'Nhẹ nhàng & Ân cần 🌸',
        'desc': 'Meow sẽ nhắc nhở nhẹ nhàng, không áp lực',
        'icon': Icons.favorite_outline,
      },
      {
        'key': 'strict',
        'label': 'Nghiêm túc & Quyết tâm 💪',
        'desc': 'Meow sẽ thúc giục mạnh mẽ để bạn đạt mục tiêu',
        'icon': Icons.fitness_center_outlined,
      },
    ];

    return _StepWrapper(
      subtitle: 'Bạn muốn Meow nhắc nhở bạn theo phong cách nào?',
      nextLabel: 'Hoàn thành 🎉',
      onNext: _saveAndFinish,
      isLoading: _saving,
      child: Column(
        children: styles.map((style) {
          final key = style['key'] as String;
          final selected = _motivationStyle == key;
          return GestureDetector(
            onTap: () => setState(() => _motivationStyle = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? _primary.withOpacity(0.1) : Colors.transparent,
                border: Border.all(
                  color: selected ? _primary : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(style['icon'] as IconData, color: selected ? _primary : Colors.grey, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected ? _primary : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          style['desc'] as String,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: _primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────
  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now().add(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Chọn ngày mục tiêu',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _saveAndFinish() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'currentLevel': _currentLevel,
        'targetLevel': _targetLevel,
        'targetDate': _targetDate != null ? Timestamp.fromDate(_targetDate!) : null,
        'dailyGoalMinutes': _dailyGoalMinutes,
        'freeTimeSlots': _freeTimeSlots.isEmpty ? ['evening'] : _freeTimeSlots,
        'motivationStyle': _motivationStyle,
        'notificationsEnabled': true,
        'goalSetAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        if (widget.isOnboarding) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('😺 Đã lưu mục tiêu học tập!'),
              backgroundColor: Color(0xFF667eea),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() {
    Navigator.of(context).pop();
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _StepWrapper extends StatelessWidget {
  final String subtitle;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final bool isLoading;

  const _StepWrapper({
    required this.subtitle,
    required this.child,
    required this.onNext,
    this.nextLabel = 'Tiếp theo',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Expanded(child: SingleChildScrollView(child: child)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      nextLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String level;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  static const _primary = Color(0xFF667eea);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? _primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  level,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              description,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? _primary : null,
              ),
            ),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, color: _primary),
          ],
        ),
      ),
    );
  }
}
