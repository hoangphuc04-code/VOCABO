import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_service.dart';

/// FarmService — quản lý farm/garden
///
/// Firestore:
/// farms/{uid}
///   - plots: [{plotId, cropType, plantedAt, stage, isReady}]
///   - animals: [{animalId, type, name, lastFedAt, lastCollectedAt, level}]
///   - fishPond: [{fishId, type, addedAt, isReady}]
///   - warehouse: {carrot: 0, tomato: 0, ...}
///   - warehouseCapacity: 100
///   - unlockedPlots: 6
///   - unlockedAnimalSlots: 4
///   - unlockedFishSlots: 6

// ─── Crop Data ────────────────────────────────────────────────────────────────

class CropInfo {
  final String type;
  final String emoji;
  final Duration growTime;
  final int sellPrice;
  final int seedCost;

  const CropInfo({
    required this.type,
    required this.emoji,
    required this.growTime,
    required this.sellPrice,
    required this.seedCost,
  });
}

const Map<String, CropInfo> kCrops = {
  'carrot':      CropInfo(type: 'carrot',      emoji: '🥕', growTime: Duration(hours: 2),  sellPrice: 5,  seedCost: 2),
  'tomato':      CropInfo(type: 'tomato',      emoji: '🍅', growTime: Duration(hours: 4),  sellPrice: 8,  seedCost: 3),
  'corn':        CropInfo(type: 'corn',        emoji: '🌽', growTime: Duration(hours: 6),  sellPrice: 12, seedCost: 5),
  'strawberry':  CropInfo(type: 'strawberry',  emoji: '🍓', growTime: Duration(hours: 8),  sellPrice: 15, seedCost: 6),
  'wheat':       CropInfo(type: 'wheat',       emoji: '🌾', growTime: Duration(hours: 1),  sellPrice: 3,  seedCost: 1),
  'potato':      CropInfo(type: 'potato',      emoji: '🥔', growTime: Duration(hours: 3),  sellPrice: 6,  seedCost: 2),
  'watermelon':  CropInfo(type: 'watermelon',  emoji: '🍉', growTime: Duration(hours: 12), sellPrice: 25, seedCost: 10),
  'pumpkin':     CropInfo(type: 'pumpkin',     emoji: '🎃', growTime: Duration(hours: 10), sellPrice: 20, seedCost: 8),
};

// ─── Animal Data ──────────────────────────────────────────────────────────────

class AnimalInfo {
  final String type;
  final String emoji;
  final Duration productionTime;
  final String product;
  final String productEmoji;
  final int productValue;
  final int feedCost;

  const AnimalInfo({
    required this.type,
    required this.emoji,
    required this.productionTime,
    required this.product,
    required this.productEmoji,
    required this.productValue,
    required this.feedCost,
  });
}

const Map<String, AnimalInfo> kAnimals = {
  'chicken': AnimalInfo(type: 'chicken', emoji: '🐔', productionTime: Duration(hours: 4),  product: 'egg',     productEmoji: '🥚', productValue: 8,  feedCost: 3),
  'duck':    AnimalInfo(type: 'duck',    emoji: '🦆', productionTime: Duration(hours: 6),  product: 'feather', productEmoji: '🪶', productValue: 10, feedCost: 4),
  'cow':     AnimalInfo(type: 'cow',     emoji: '🐄', productionTime: Duration(hours: 8),  product: 'milk',    productEmoji: '🥛', productValue: 15, feedCost: 6),
  'pig':     AnimalInfo(type: 'pig',     emoji: '🐷', productionTime: Duration(hours: 12), product: 'meat',    productEmoji: '🥩', productValue: 20, feedCost: 8),
};

// ─── Fish Data ────────────────────────────────────────────────────────────────

class FishInfo {
  final String type;
  final String emoji;
  final Duration growTime;
  final int sellPrice;

  const FishInfo({
    required this.type,
    required this.emoji,
    required this.growTime,
    required this.sellPrice,
  });
}

const Map<String, FishInfo> kFish = {
  'fish':     FishInfo(type: 'fish',     emoji: '🐟', growTime: Duration(hours: 3), sellPrice: 6),
  'carp':     FishInfo(type: 'carp',     emoji: '🐠', growTime: Duration(hours: 5), sellPrice: 10),
  'salmon':   FishInfo(type: 'salmon',   emoji: '🐡', growTime: Duration(hours: 8), sellPrice: 18),
  'goldfish': FishInfo(type: 'goldfish', emoji: '🐟', growTime: Duration(hours: 2), sellPrice: 4),
};

// ─── Models ───────────────────────────────────────────────────────────────────

class PlotData {
  final String plotId;
  final String? cropType;
  final DateTime? plantedAt;
  final String stage; // 'empty' | 'growing' | 'ready'
  final bool isReady;

  const PlotData({
    required this.plotId,
    this.cropType,
    this.plantedAt,
    this.stage = 'empty',
    this.isReady = false,
  });

  factory PlotData.fromMap(Map<String, dynamic> m) {
    return PlotData(
      plotId: m['plotId'] as String? ?? '',
      cropType: m['cropType'] as String?,
      plantedAt: m['plantedAt'] != null
          ? (m['plantedAt'] as Timestamp).toDate()
          : null,
      stage: m['stage'] as String? ?? 'empty',
      isReady: m['isReady'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'plotId': plotId,
    'cropType': cropType,
    'plantedAt': plantedAt != null ? Timestamp.fromDate(plantedAt!) : null,
    'stage': stage,
    'isReady': isReady,
  };

  PlotData copyWith({
    String? cropType,
    DateTime? plantedAt,
    String? stage,
    bool? isReady,
  }) {
    return PlotData(
      plotId: plotId,
      cropType: cropType ?? this.cropType,
      plantedAt: plantedAt ?? this.plantedAt,
      stage: stage ?? this.stage,
      isReady: isReady ?? this.isReady,
    );
  }

  /// Tính stage dựa trên thời gian trồng
  PlotData withComputedStage() {
    if (cropType == null || plantedAt == null) {
      return copyWith(stage: 'empty', isReady: false);
    }
    final info = kCrops[cropType!];
    if (info == null) return this;
    final elapsed = DateTime.now().difference(plantedAt!);
    if (elapsed >= info.growTime) {
      return copyWith(stage: 'ready', isReady: true);
    }
    return copyWith(stage: 'growing', isReady: false);
  }

  double get growthProgress {
    if (cropType == null || plantedAt == null) return 0;
    final info = kCrops[cropType!];
    if (info == null) return 0;
    final elapsed = DateTime.now().difference(plantedAt!);
    return (elapsed.inSeconds / info.growTime.inSeconds).clamp(0.0, 1.0);
  }

  Duration get timeRemaining {
    if (cropType == null || plantedAt == null) return Duration.zero;
    final info = kCrops[cropType!];
    if (info == null) return Duration.zero;
    final elapsed = DateTime.now().difference(plantedAt!);
    final remaining = info.growTime - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class AnimalData {
  final String animalId;
  final String type;
  final String name;
  final DateTime? lastFedAt;
  final DateTime? lastCollectedAt;
  final int level;

  const AnimalData({
    required this.animalId,
    required this.type,
    required this.name,
    this.lastFedAt,
    this.lastCollectedAt,
    this.level = 1,
  });

  factory AnimalData.fromMap(Map<String, dynamic> m) {
    return AnimalData(
      animalId: m['animalId'] as String? ?? '',
      type: m['type'] as String? ?? '',
      name: m['name'] as String? ?? '',
      lastFedAt: m['lastFedAt'] != null
          ? (m['lastFedAt'] as Timestamp).toDate()
          : null,
      lastCollectedAt: m['lastCollectedAt'] != null
          ? (m['lastCollectedAt'] as Timestamp).toDate()
          : null,
      level: (m['level'] ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'animalId': animalId,
    'type': type,
    'name': name,
    'lastFedAt': lastFedAt != null ? Timestamp.fromDate(lastFedAt!) : null,
    'lastCollectedAt': lastCollectedAt != null ? Timestamp.fromDate(lastCollectedAt!) : null,
    'level': level,
  };

  bool get isProductReady {
    final info = kAnimals[type];
    if (info == null || lastCollectedAt == null) return lastFedAt != null;
    return DateTime.now().difference(lastCollectedAt!) >= info.productionTime;
  }

  double get productionProgress {
    final info = kAnimals[type];
    if (info == null || lastCollectedAt == null) return 0;
    final elapsed = DateTime.now().difference(lastCollectedAt!);
    return (elapsed.inSeconds / info.productionTime.inSeconds).clamp(0.0, 1.0);
  }

  Duration get timeUntilProduct {
    final info = kAnimals[type];
    if (info == null || lastCollectedAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(lastCollectedAt!);
    final remaining = info.productionTime - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class FishData {
  final String fishId;
  final String type;
  final DateTime addedAt;
  final bool isReady;

  const FishData({
    required this.fishId,
    required this.type,
    required this.addedAt,
    this.isReady = false,
  });

  factory FishData.fromMap(Map<String, dynamic> m) {
    return FishData(
      fishId: m['fishId'] as String? ?? '',
      type: m['type'] as String? ?? '',
      addedAt: m['addedAt'] != null
          ? (m['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
      isReady: m['isReady'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'fishId': fishId,
    'type': type,
    'addedAt': Timestamp.fromDate(addedAt),
    'isReady': isReady,
  };

  FishData withComputedReady() {
    final info = kFish[type];
    if (info == null) return this;
    final elapsed = DateTime.now().difference(addedAt);
    return FishData(
      fishId: fishId,
      type: type,
      addedAt: addedAt,
      isReady: elapsed >= info.growTime,
    );
  }

  double get growthProgress {
    final info = kFish[type];
    if (info == null) return 0;
    final elapsed = DateTime.now().difference(addedAt);
    return (elapsed.inSeconds / info.growTime.inSeconds).clamp(0.0, 1.0);
  }
}

class FarmData {
  final List<PlotData> plots;
  final List<AnimalData> animals;
  final List<FishData> fishPond;
  final Map<String, int> warehouse;
  final int warehouseCapacity;
  final int unlockedPlots;
  final int unlockedAnimalSlots;
  final int unlockedFishSlots;

  const FarmData({
    required this.plots,
    required this.animals,
    required this.fishPond,
    required this.warehouse,
    this.warehouseCapacity = 100,
    this.unlockedPlots = 6,
    this.unlockedAnimalSlots = 4,
    this.unlockedFishSlots = 6,
  });

  factory FarmData.fromMap(Map<String, dynamic> m) {
    final plotsList = (m['plots'] as List? ?? [])
        .map((e) => PlotData.fromMap(Map<String, dynamic>.from(e)).withComputedStage())
        .toList();

    final animalsList = (m['animals'] as List? ?? [])
        .map((e) => AnimalData.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final fishList = (m['fishPond'] as List? ?? [])
        .map((e) => FishData.fromMap(Map<String, dynamic>.from(e)).withComputedReady())
        .toList();

    final warehouseMap = Map<String, int>.from(
      (m['warehouse'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
    );

    return FarmData(
      plots: plotsList,
      animals: animalsList,
      fishPond: fishList,
      warehouse: warehouseMap,
      warehouseCapacity: (m['warehouseCapacity'] ?? 100).toInt(),
      unlockedPlots: (m['unlockedPlots'] ?? 6).toInt(),
      unlockedAnimalSlots: (m['unlockedAnimalSlots'] ?? 4).toInt(),
      unlockedFishSlots: (m['unlockedFishSlots'] ?? 6).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'plots': plots.map((p) => p.toMap()).toList(),
    'animals': animals.map((a) => a.toMap()).toList(),
    'fishPond': fishPond.map((f) => f.toMap()).toList(),
    'warehouse': warehouse,
    'warehouseCapacity': warehouseCapacity,
    'unlockedPlots': unlockedPlots,
    'unlockedAnimalSlots': unlockedAnimalSlots,
    'unlockedFishSlots': unlockedFishSlots,
  };

  static FarmData defaultFarm() {
    final plots = List.generate(
      6,
      (i) => PlotData(plotId: 'plot_$i'),
    );
    return FarmData(
      plots: plots,
      animals: [],
      fishPond: [],
      warehouse: {},
    );
  }

  int get warehouseUsed =>
      warehouse.values.fold(0, (sum, v) => sum + v);

  bool get warehouseFull => warehouseUsed >= warehouseCapacity;

  int get readyCrops => plots.where((p) => p.isReady).length;
  int get readyAnimals => animals.where((a) => a.isProductReady).length;
  int get readyFish => fishPond.where((f) => f.isReady).length;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class FarmService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static DocumentReference get _farmRef => _db.collection('farms').doc(_uid);

  // Flag tránh init lại nhiều lần trong cùng session
  static String _initializedUid = '';

  // ── Stream & Fetch ────────────────────────────────────

  static Stream<FarmData> farmStream() {
    if (_uid.isEmpty) return Stream.value(FarmData.defaultFarm());
    return _farmRef.snapshots().map((doc) {
      if (!doc.exists) return FarmData.defaultFarm();
      return FarmData.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  static Future<FarmData> getFarm() async {
    if (_uid.isEmpty) return FarmData.defaultFarm();
    final doc = await _farmRef.get();
    if (!doc.exists) return FarmData.defaultFarm();
    return FarmData.fromMap(doc.data() as Map<String, dynamic>);
  }

  // ── Init ──────────────────────────────────────────────

  static Future<void> initFarmIfNeeded() async {
    if (_uid.isEmpty) return;
    // Chỉ init 1 lần per session per user
    if (_initializedUid == _uid) return;
    _initializedUid = _uid;
    final snap = await _farmRef.get();
    if (!snap.exists) {
      await _farmRef.set(FarmData.defaultFarm().toMap());
    }
  }

  // ── Plots / Crops ─────────────────────────────────────

  /// Trồng cây vào ô đất. Tốn seedCost coin.
  static Future<bool> plantCrop(String plotId, String cropType) async {
    if (_uid.isEmpty) return false;
    final info = kCrops[cropType];
    if (info == null) return false;

    // Kiểm tra coin
    final ok = await GameService.spendCoins(info.seedCost);
    if (!ok) return false;

    final farm = await getFarm();
    final idx = farm.plots.indexWhere((p) => p.plotId == plotId);
    if (idx == -1) return false;
    if (farm.plots[idx].stage != 'empty') return false;

    final updated = farm.plots[idx].copyWith(
      cropType: cropType,
      plantedAt: DateTime.now(),
      stage: 'growing',
      isReady: false,
    );

    final newPlots = List<PlotData>.from(farm.plots);
    newPlots[idx] = updated;

    await _farmRef.update({
      'plots': newPlots.map((p) => p.toMap()).toList(),
    });
    return true;
  }

  /// Thu hoạch cây → thêm vào warehouse
  static Future<bool> harvestCrop(String plotId) async {
    if (_uid.isEmpty) return false;
    final farm = await getFarm();
    final idx = farm.plots.indexWhere((p) => p.plotId == plotId);
    if (idx == -1) return false;

    final plot = farm.plots[idx].withComputedStage();
    if (!plot.isReady || plot.cropType == null) return false;

    // Thêm vào warehouse
    final added = await addToWarehouse(plot.cropType!, 1);
    if (!added) return false;

    // Reset ô đất
    final newPlots = List<PlotData>.from(farm.plots);
    newPlots[idx] = PlotData(plotId: plotId);

    await _farmRef.update({
      'plots': newPlots.map((p) => p.toMap()).toList(),
    });
    return true;
  }

  // ── Animals ───────────────────────────────────────────

  /// Mua và thêm động vật mới
  static Future<bool> addAnimal(String animalType, String name) async {
    if (_uid.isEmpty) return false;
    final info = kAnimals[animalType];
    if (info == null) return false;

    final farm = await getFarm();
    if (farm.animals.length >= farm.unlockedAnimalSlots) return false;

    final animal = AnimalData(
      animalId: 'animal_${DateTime.now().millisecondsSinceEpoch}',
      type: animalType,
      name: name.isEmpty ? info.emoji : name,
      lastFedAt: DateTime.now(),
      lastCollectedAt: DateTime.now(),
    );

    final newAnimals = [...farm.animals, animal];
    await _farmRef.update({
      'animals': newAnimals.map((a) => a.toMap()).toList(),
    });
    return true;
  }

  /// Cho động vật ăn
  static Future<bool> feedAnimal(String animalId) async {
    if (_uid.isEmpty) return false;
    final farm = await getFarm();
    final idx = farm.animals.indexWhere((a) => a.animalId == animalId);
    if (idx == -1) return false;

    final info = kAnimals[farm.animals[idx].type];
    if (info == null) return false;

    // Tốn feedCost coin
    final ok = await GameService.spendCoins(info.feedCost);
    if (!ok) return false;

    final newAnimals = List<AnimalData>.from(farm.animals);
    newAnimals[idx] = AnimalData(
      animalId: farm.animals[idx].animalId,
      type: farm.animals[idx].type,
      name: farm.animals[idx].name,
      lastFedAt: DateTime.now(),
      lastCollectedAt: farm.animals[idx].lastCollectedAt,
      level: farm.animals[idx].level,
    );

    await _farmRef.update({
      'animals': newAnimals.map((a) => a.toMap()).toList(),
    });
    return true;
  }

  /// Thu sản phẩm từ động vật → warehouse
  static Future<bool> collectAnimalProduct(String animalId) async {
    if (_uid.isEmpty) return false;
    final farm = await getFarm();
    final idx = farm.animals.indexWhere((a) => a.animalId == animalId);
    if (idx == -1) return false;

    final animal = farm.animals[idx];
    if (!animal.isProductReady) return false;

    final info = kAnimals[animal.type];
    if (info == null) return false;

    final added = await addToWarehouse(info.product, 1);
    if (!added) return false;

    final newAnimals = List<AnimalData>.from(farm.animals);
    newAnimals[idx] = AnimalData(
      animalId: animal.animalId,
      type: animal.type,
      name: animal.name,
      lastFedAt: animal.lastFedAt,
      lastCollectedAt: DateTime.now(),
      level: animal.level,
    );

    await _farmRef.update({
      'animals': newAnimals.map((a) => a.toMap()).toList(),
    });
    return true;
  }

  // ── Fish Pond ─────────────────────────────────────────

  /// Thêm cá vào hồ
  static Future<bool> addFish(String fishType) async {
    if (_uid.isEmpty) return false;
    final info = kFish[fishType];
    if (info == null) return false;

    final farm = await getFarm();
    if (farm.fishPond.length >= farm.unlockedFishSlots) return false;

    final fish = FishData(
      fishId: 'fish_${DateTime.now().millisecondsSinceEpoch}',
      type: fishType,
      addedAt: DateTime.now(),
    );

    final newFish = [...farm.fishPond, fish];
    await _farmRef.update({
      'fishPond': newFish.map((f) => f.toMap()).toList(),
    });
    return true;
  }

  /// Thu hoạch cá → warehouse
  static Future<bool> collectFish(String fishId) async {
    if (_uid.isEmpty) return false;
    final farm = await getFarm();
    final idx = farm.fishPond.indexWhere((f) => f.fishId == fishId);
    if (idx == -1) return false;

    final fish = farm.fishPond[idx].withComputedReady();
    if (!fish.isReady) return false;

    final added = await addToWarehouse(fish.type, 1);
    if (!added) return false;

    final newFish = List<FishData>.from(farm.fishPond)..removeAt(idx);
    await _farmRef.update({
      'fishPond': newFish.map((f) => f.toMap()).toList(),
    });
    return true;
  }

  // ── Warehouse ─────────────────────────────────────────

  static Future<Map<String, int>> getWarehouse() async {
    final farm = await getFarm();
    return farm.warehouse;
  }

  static Future<bool> addToWarehouse(String itemType, int amount) async {
    if (_uid.isEmpty) return false;
    final farm = await getFarm();
    if (farm.warehouseUsed + amount > farm.warehouseCapacity) return false;

    final newWarehouse = Map<String, int>.from(farm.warehouse);
    newWarehouse[itemType] = (newWarehouse[itemType] ?? 0) + amount;

    await _farmRef.update({'warehouse': newWarehouse});
    return true;
  }

  static Future<bool> removeFromWarehouse(String itemType, int amount) async {
    if (_uid.isEmpty) return false;
    final farm = await getFarm();
    final current = farm.warehouse[itemType] ?? 0;
    if (current < amount) return false;

    final newWarehouse = Map<String, int>.from(farm.warehouse);
    newWarehouse[itemType] = current - amount;
    if (newWarehouse[itemType] == 0) newWarehouse.remove(itemType);

    await _farmRef.update({'warehouse': newWarehouse});
    return true;
  }

  /// Bán item từ kho → nhận coin
  static Future<int> sellFromWarehouse(String itemType, int amount) async {
    if (_uid.isEmpty) return 0;
    final removed = await removeFromWarehouse(itemType, amount);
    if (!removed) return 0;

    int price = 0;
    if (kCrops.containsKey(itemType)) {
      price = kCrops[itemType]!.sellPrice * amount;
    } else if (kFish.containsKey(itemType)) {
      price = kFish[itemType]!.sellPrice * amount;
    } else {
      // Animal products
      for (final a in kAnimals.values) {
        if (a.product == itemType) {
          price = a.productValue * amount;
          break;
        }
      }
    }

    if (price > 0) await GameService.addCoins(price);
    return price;
  }

  // ── Unlock ────────────────────────────────────────────

  /// Mở thêm ô đất (50 coin/ô)
  static Future<bool> unlockMorePlots(int count) async {
    if (_uid.isEmpty) return false;
    final cost = count * 50;
    final ok = await GameService.spendCoins(cost);
    if (!ok) return false;

    await _farmRef.update({
      'unlockedPlots': FieldValue.increment(count),
      'plots': FieldValue.arrayUnion(
        List.generate(
          count,
          (i) => PlotData(
            plotId: 'plot_${DateTime.now().millisecondsSinceEpoch}_$i',
          ).toMap(),
        ),
      ),
    });
    return true;
  }

  /// Mở thêm slot động vật (80 coin/slot)
  static Future<bool> unlockAnimalSlot() async {
    if (_uid.isEmpty) return false;
    final ok = await GameService.spendCoins(80);
    if (!ok) return false;
    await _farmRef.update({'unlockedAnimalSlots': FieldValue.increment(1)});
    return true;
  }

  /// Mở thêm slot cá (60 coin/slot)
  static Future<bool> unlockFishSlot() async {
    if (_uid.isEmpty) return false;
    final ok = await GameService.spendCoins(60);
    if (!ok) return false;
    await _farmRef.update({'unlockedFishSlots': FieldValue.increment(1)});
    return true;
  }
}
