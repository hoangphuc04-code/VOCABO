import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'farm_service.dart';
import 'game_service.dart';

/// MissionService — nhiệm vụ giao hàng hàng ngày
///
/// Firestore:
/// missions/{uid}/daily/{date}
///   - missions: [{id, type, title, description, requirement, progress, reward, deadline, isCompleted}]
///   - generatedAt

// ─── Models ───────────────────────────────────────────────────────────────────

class MissionReward {
  final int coins;
  final int xp;

  const MissionReward({required this.coins, required this.xp});

  factory MissionReward.fromMap(Map<String, dynamic> m) => MissionReward(
        coins: (m['coins'] ?? 0).toInt(),
        xp: (m['xp'] ?? 0).toInt(),
      );

  Map<String, dynamic> toMap() => {'coins': coins, 'xp': xp};
}

class MissionRequirement {
  final String itemType;
  final int amount;

  const MissionRequirement({required this.itemType, required this.amount});

  factory MissionRequirement.fromMap(Map<String, dynamic> m) =>
      MissionRequirement(
        itemType: m['itemType'] as String? ?? '',
        amount: (m['amount'] ?? 1).toInt(),
      );

  Map<String, dynamic> toMap() => {'itemType': itemType, 'amount': amount};
}

class MissionData {
  final String id;
  final String type; // 'delivery' | 'harvest' | 'collect' | 'sell'
  final String title;
  final String description;
  final MissionRequirement requirement;
  final int progress;
  final MissionReward reward;
  final DateTime deadline;
  final bool isCompleted;

  const MissionData({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.requirement,
    required this.progress,
    required this.reward,
    required this.deadline,
    this.isCompleted = false,
  });

  factory MissionData.fromMap(Map<String, dynamic> m) => MissionData(
        id: m['id'] as String? ?? '',
        type: m['type'] as String? ?? 'delivery',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        requirement: MissionRequirement.fromMap(
            Map<String, dynamic>.from(m['requirement'] ?? {})),
        progress: (m['progress'] ?? 0).toInt(),
        reward: MissionReward.fromMap(
            Map<String, dynamic>.from(m['reward'] ?? {})),
        deadline: m['deadline'] != null
            ? (m['deadline'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(hours: 24)),
        isCompleted: m['isCompleted'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'requirement': requirement.toMap(),
        'progress': progress,
        'reward': reward.toMap(),
        'deadline': Timestamp.fromDate(deadline),
        'isCompleted': isCompleted,
      };

  double get progressPercent =>
      (progress / requirement.amount).clamp(0.0, 1.0);

  bool get isExpired => DateTime.now().isAfter(deadline);

  bool get canComplete =>
      !isCompleted && !isExpired && progress >= requirement.amount;

  MissionData copyWith({int? progress, bool? isCompleted}) => MissionData(
        id: id,
        type: type,
        title: title,
        description: description,
        requirement: requirement,
        progress: progress ?? this.progress,
        reward: reward,
        deadline: deadline,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MissionService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // In-memory cache: tránh Firestore read mỗi lần vào màn hình
  static String _generatedDateKey = '';
  static final _rng = Random();

  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static DocumentReference get _todayRef => _db
      .collection('missions')
      .doc(_uid)
      .collection('daily')
      .doc(_todayKey);

  // ── Tạo missions hàng ngày ────────────────────────────

  static Future<void> generateDailyMissions() async {
    if (_uid.isEmpty) return;

    // Nếu đã generate hôm nay trong session này → skip Firestore read
    final todayKey = _todayKey;
    final cacheKey = '${_uid}_$todayKey';
    if (_generatedDateKey == cacheKey) return;

    final snap = await _todayRef.get();
    if (snap.exists) {
      _generatedDateKey = cacheKey; // cache lại
      return; // Đã tạo hôm nay
    }

    final missions = _buildMissions();
    await _todayRef.set({
      'missions': missions.map((m) => m.toMap()).toList(),
      'generatedAt': FieldValue.serverTimestamp(),
    });
    _generatedDateKey = cacheKey;
  }

  static List<MissionData> _buildMissions() {
    final deadline = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      23,
      59,
      59,
    );

    final allCrops = kCrops.keys.toList();
    final allAnimals = kAnimals.keys.toList();

    final templates = <Map<String, dynamic>>[
      // Delivery missions
      {
        'type': 'delivery',
        'itemType': allCrops[_rng.nextInt(allCrops.length)],
        'amount': _rng.nextInt(3) + 2,
        'coinReward': 30,
        'xpReward': 20,
      },
      // Harvest missions
      {
        'type': 'harvest',
        'itemType': allCrops[_rng.nextInt(allCrops.length)],
        'amount': _rng.nextInt(2) + 1,
        'coinReward': 20,
        'xpReward': 15,
      },
      // Collect animal product
      {
        'type': 'collect',
        'itemType': kAnimals[allAnimals[_rng.nextInt(allAnimals.length)]]!.product,
        'amount': _rng.nextInt(2) + 1,
        'coinReward': 25,
        'xpReward': 18,
      },
    ];

    // Shuffle để đa dạng
    templates.shuffle(_rng);

    return List.generate(3, (i) {
      final t = templates[i];
      final type = t['type'] as String;
      final itemType = t['itemType'] as String;
      final amount = t['amount'] as int;
      final emoji = _emojiFor(itemType);

      String title;
      String description;

      switch (type) {
        case 'delivery':
          title = 'Giao hàng cho NPC';
          description = 'Giao $amount $emoji $itemType cho người dân làng';
          break;
        case 'harvest':
          title = 'Thu hoạch mùa vụ';
          description = 'Thu hoạch $amount $emoji $itemType từ vườn';
          break;
        case 'collect':
          title = 'Thu sản phẩm chăn nuôi';
          description = 'Thu $amount $emoji $itemType từ chuồng trại';
          break;
        case 'sell':
          title = 'Bán hàng trên chợ';
          description = 'Bán $amount $emoji $itemType trên chợ';
          break;
        default:
          title = 'Nhiệm vụ';
          description = 'Hoàn thành nhiệm vụ';
      }

      return MissionData(
        id: 'mission_${_todayKey}_$i',
        type: type,
        title: title,
        description: description,
        requirement: MissionRequirement(itemType: itemType, amount: amount),
        progress: 0,
        reward: MissionReward(
          coins: t['coinReward'] as int,
          xp: t['xpReward'] as int,
        ),
        deadline: deadline,
      );
    });
  }

  static String _emojiFor(String itemType) {
    if (kCrops.containsKey(itemType)) return kCrops[itemType]!.emoji;
    if (kFish.containsKey(itemType)) return kFish[itemType]!.emoji;
    for (final a in kAnimals.values) {
      if (a.product == itemType) return a.productEmoji;
    }
    return '📦';
  }

  // ── Lấy missions hôm nay ──────────────────────────────

  static Future<List<MissionData>> getMissions() async {
    if (_uid.isEmpty) return [];
    await generateDailyMissions();
    final snap = await _todayRef.get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>;
    final list = data['missions'] as List? ?? [];
    return list
        .map((e) => MissionData.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Stream missions ───────────────────────────────────

  static Stream<List<MissionData>> missionsStream() {
    if (_uid.isEmpty) return Stream.value([]);
    // Đảm bảo missions được tạo
    generateDailyMissions();
    return _todayRef.snapshots().map((snap) {
      if (!snap.exists) return <MissionData>[];
      final data = snap.data() as Map<String, dynamic>;
      final list = data['missions'] as List? ?? [];
      return list
          .map((e) => MissionData.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  // ── Cập nhật tiến độ ─────────────────────────────────

  static Future<void> updateMissionProgress(
      String missionId, int progress) async {
    if (_uid.isEmpty) return;
    final missions = await getMissions();
    final idx = missions.indexWhere((m) => m.id == missionId);
    if (idx == -1) return;

    final updated = missions[idx].copyWith(progress: progress);
    final newList = List<MissionData>.from(missions);
    newList[idx] = updated;

    await _todayRef.update({
      'missions': newList.map((m) => m.toMap()).toList(),
    });
  }

  // ── Hoàn thành mission ────────────────────────────────

  static Future<bool> completeMission(String missionId) async {
    if (_uid.isEmpty) return false;
    final missions = await getMissions();
    final idx = missions.indexWhere((m) => m.id == missionId);
    if (idx == -1) return false;

    final mission = missions[idx];
    if (!mission.canComplete) return false;

    // Lấy item từ kho (delivery mission)
    if (mission.type == 'delivery') {
      final removed = await FarmService.removeFromWarehouse(
        mission.requirement.itemType,
        mission.requirement.amount,
      );
      if (!removed) return false;
    }

    // Nhận thưởng
    await GameService.addCoins(mission.reward.coins);

    // Cộng XP
    await _db.collection('users').doc(_uid).update({
      'xp': FieldValue.increment(mission.reward.xp),
    });

    // Đánh dấu hoàn thành
    final updated = mission.copyWith(isCompleted: true);
    final newList = List<MissionData>.from(missions);
    newList[idx] = updated;

    await _todayRef.update({
      'missions': newList.map((m) => m.toMap()).toList(),
    });
    return true;
  }

  // ── Lịch sử missions ─────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMissionHistory(
      {int days = 7}) async {
    if (_uid.isEmpty) return [];
    final results = <Map<String, dynamic>>[];

    for (int i = 1; i <= days; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final snap = await _db
          .collection('missions')
          .doc(_uid)
          .collection('daily')
          .doc(key)
          .get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final list = data['missions'] as List? ?? [];
        final missions = list
            .map((e) => MissionData.fromMap(Map<String, dynamic>.from(e)))
            .where((m) => m.isCompleted)
            .toList();
        if (missions.isNotEmpty) {
          results.add({'date': key, 'missions': missions});
        }
      }
    }
    return results;
  }
}
