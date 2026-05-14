import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// house_service.dart — v2: multi-pet, egg hatching, evolution, house level

/// HouseService — quản lý nhà, vật phẩm, pet
///
/// Firestore:
/// houses/{uid}
///   - wallpaper: string (item id)
///   - floorType: string
///   - placedItems: [{id, x, y, rotation}]
///   - ownedItems: [item ids]
///   - pet: {type, name, hunger, happiness, lastFedAt, level, xp}
///   - visitors: [{uid, name, photo, visitedAt}]
class HouseService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Flag tránh init lại nhiều lần trong cùng session
  static String _initializedUid = '';

  // ── Lấy dữ liệu nhà ──────────────────────────────────
  static Stream<HouseData> houseStream([String? uid]) {
    final id = uid ?? _uid;
    if (id.isEmpty) return Stream.value(HouseData.defaultHouse());
    return _db.collection('houses').doc(id).snapshots().map((doc) {
      if (!doc.exists) return HouseData.defaultHouse();
      return HouseData.fromMap(doc.data()!);
    });
  }

  static Future<HouseData> getHouse([String? uid]) async {
    final id = uid ?? _uid;
    if (id.isEmpty) return HouseData.defaultHouse();
    final doc = await _db.collection('houses').doc(id).get();
    if (!doc.exists) return HouseData.defaultHouse();
    return HouseData.fromMap(doc.data()!);
  }

  // ── Khởi tạo nhà cho user mới ─────────────────────────
  static Future<void> initHouseIfNeeded() async {
    if (_uid.isEmpty) return;
    // Chỉ init 1 lần per session per user
    if (_initializedUid == _uid) return;
    _initializedUid = _uid;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(HouseData.defaultHouse().toMap());
    }
  }

  // ── Đặt vật phẩm vào phòng ───────────────────────────
  static Future<bool> placeItem(PlacedItem item) async {
    if (_uid.isEmpty) return false;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final placed = List<Map<String, dynamic>>.from(
        (data['placedItems'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

    // Xoá item cũ nếu đã có cùng instanceId
    placed.removeWhere((p) => p['instanceId'] == item.instanceId);
    placed.add(item.toMap());

    await ref.update({'placedItems': placed});
    return true;
  }

  // ── Xoá vật phẩm khỏi phòng ──────────────────────────
  static Future<void> removeItem(String instanceId) async {
    if (_uid.isEmpty) return;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final placed = List<Map<String, dynamic>>.from(
        (data['placedItems'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);
    placed.removeWhere((p) => p['instanceId'] == instanceId);
    await ref.update({'placedItems': placed});
  }

  // ── Đổi giấy dán tường / sàn ─────────────────────────
  static Future<void> setWallpaper(String itemId) async {
    if (_uid.isEmpty) return;
    await _db.collection('houses').doc(_uid).update({'wallpaper': itemId});
  }

  static Future<void> setFloor(String itemId) async {
    if (_uid.isEmpty) return;
    await _db.collection('houses').doc(_uid).update({'floorType': itemId});
  }

  // ── Mua vật phẩm ─────────────────────────────────────
  static Future<ShopResult> buyItem(HouseItem item) async {
    if (_uid.isEmpty) return ShopResult.error('Chưa đăng nhập');

    final userRef = _db.collection('users').doc(_uid);
    final houseRef = _db.collection('houses').doc(_uid);
    bool ok = false;
    String msg = '';

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final houseSnap = await tx.get(houseRef);

      final coins = (userSnap.data()?['coins'] ?? 0).toInt();
      final owned = List<String>.from(houseSnap.data()?['ownedItems'] ?? []);

      if (owned.contains(item.id)) {
        msg = 'Bạn đã sở hữu vật phẩm này!';
        return;
      }
      if (coins < item.price) {
        msg = 'Không đủ 🪙 (cần ${item.price}, có $coins)';
        return;
      }

      tx.update(userRef, {'coins': coins - item.price});
      tx.update(houseRef, {
        'ownedItems': [...owned, item.id],
      });
      ok = true;
      msg = '✅ Đã mua ${item.name}!';
    });

    return ok ? ShopResult.success(msg) : ShopResult.error(msg);
  }

  // ── Pet: cho ăn ───────────────────────────────────────
  static Future<PetFeedResult> feedPet([String? petId]) async {
    if (_uid.isEmpty) return PetFeedResult(success: false, message: 'Lỗi');

    final ref = _db.collection('houses').doc(_uid);
    bool ok = false;
    String msg = '';

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final pets = List<Map<String, dynamic>>.from(
          (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

      final idx = petId != null
          ? pets.indexWhere((p) => p['id'] == petId)
          : 0;
      if (idx < 0) { msg = 'Không tìm thấy pet'; return; }

      final pet = pets[idx];
      final lastFed = (pet['lastFedAt'] as Timestamp?)?.toDate();
      if (lastFed != null) {
        final elapsed = DateTime.now().difference(lastFed);
        if (elapsed.inMinutes < 30) {
          msg = 'Pet chưa đói! Chờ thêm ${30 - elapsed.inMinutes} phút';
          return;
        }
      }

      pets[idx] = {
        ...pet,
        'hunger': ((pet['hunger'] ?? 50) as num).toInt().clamp(0, 100) + 30 > 100
            ? 100
            : ((pet['hunger'] ?? 50) as num).toInt() + 30,
        'happiness': ((pet['happiness'] ?? 50) as num).toInt().clamp(0, 100) + 10 > 100
            ? 100
            : ((pet['happiness'] ?? 50) as num).toInt() + 10,
        'xp': ((pet['xp'] ?? 0) as num).toInt() + 5,
        'lastFedAt': Timestamp.now(),
      };
      tx.update(ref, {'pets': pets});
      ok = true;
      msg = '😋 Pet đã được cho ăn! +30 no, +10 vui';
    });

    return PetFeedResult(success: ok, message: msg);
  }

  // ── Pet: tương tác / chơi ─────────────────────────────
  static Future<PetFeedResult> playWithPet([String? petId]) async {
    if (_uid.isEmpty) return PetFeedResult(success: false, message: 'Lỗi');

    final ref = _db.collection('houses').doc(_uid);
    bool ok = false;
    String msg = '';

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final pets = List<Map<String, dynamic>>.from(
          (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

      final idx = petId != null
          ? pets.indexWhere((p) => p['id'] == petId)
          : 0;
      if (idx < 0) { msg = 'Không tìm thấy pet'; return; }

      final pet = pets[idx];
      final lastPlayed = (pet['lastPlayedAt'] as Timestamp?)?.toDate();
      if (lastPlayed != null) {
        final elapsed = DateTime.now().difference(lastPlayed);
        if (elapsed.inMinutes < 15) {
          msg = 'Pet đang mệt! Chờ thêm ${15 - elapsed.inMinutes} phút';
          return;
        }
      }

      pets[idx] = {
        ...pet,
        'happiness': ((pet['happiness'] ?? 50) as num).toInt() + 20 > 100
            ? 100
            : ((pet['happiness'] ?? 50) as num).toInt() + 20,
        'xp': ((pet['xp'] ?? 0) as num).toInt() + 10,
        'lastPlayedAt': Timestamp.now(),
      };
      tx.update(ref, {'pets': pets});
      ok = true;
      msg = '🎉 Pet rất vui! +20 hạnh phúc';
    });

    return PetFeedResult(success: ok, message: msg);
  }

  // ── Pet: đặt tên ──────────────────────────────────────
  static Future<void> namePet(String name, [String? petId]) async {
    if (_uid.isEmpty) return;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final pets = List<Map<String, dynamic>>.from(
        (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);
    final idx = petId != null ? pets.indexWhere((p) => p['id'] == petId) : 0;
    if (idx >= 0) {
      pets[idx] = {...pets[idx], 'name': name};
      await ref.update({'pets': pets});
    }
  }

  // ── Pet: thêm pet mới (ấp trứng) ─────────────────────
  static Future<String?> addPet(String species) async {
    if (_uid.isEmpty) return 'Chưa đăng nhập';

    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final houseLevel = (data['houseLevel'] ?? 1).toInt();
    final maxPets = maxPetsForHouseLevel(houseLevel);

    final pets = List<Map<String, dynamic>>.from(
        (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

    if (pets.length >= maxPets) {
      return 'Nhà level $houseLevel chỉ nuôi được $maxPets pet! Nâng cấp nhà để nuôi thêm.';
    }

    final info = kPetSpecies[species];
    if (info == null) return 'Loài pet không hợp lệ';

    // Check coins
    if (info.coinCost > 0) {
      final userSnap = await _db.collection('users').doc(_uid).get();
      final coins = (userSnap.data()?['coins'] ?? 0).toInt();
      if (coins < info.coinCost) {
        return 'Không đủ 🪙 (cần ${info.coinCost}, có $coins)';
      }
      await _db.collection('users').doc(_uid).update({
        'coins': coins - info.coinCost,
      });
    }

    final newPet = PetData.newEgg(species);
    pets.add(newPet.toMap());
    await ref.update({'pets': pets});
    return null; // success
  }

  // ── Pet: kiểm tra và nở trứng ─────────────────────────
  static Future<void> checkAndHatchEggs() async {
    if (_uid.isEmpty) return;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final pets = List<Map<String, dynamic>>.from(
        (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

    bool changed = false;
    for (int i = 0; i < pets.length; i++) {
      final pet = pets[i];
      if (pet['stage'] == 'egg') {
        final hatchAt = (pet['hatchAt'] as Timestamp?)?.toDate();
        if (hatchAt != null && DateTime.now().isAfter(hatchAt)) {
          pets[i] = {...pet, 'stage': 'baby'};
          changed = true;
        }
      }
    }
    if (changed) await ref.update({'pets': pets});
  }

  // ── Pet: tiến hóa ─────────────────────────────────────
  static Future<String?> evolvePet(String petId) async {
    if (_uid.isEmpty) return 'Chưa đăng nhập';
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final pets = List<Map<String, dynamic>>.from(
        (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

    final idx = pets.indexWhere((p) => p['id'] == petId);
    if (idx < 0) return 'Không tìm thấy pet';

    final pet = PetData.fromMap(pets[idx]);
    if (!pet.canEvolve) return 'Pet chưa đủ điều kiện tiến hóa (level ${pet._evolveLevel})';

    final nextStage = {
      'baby': 'teen',
      'teen': 'adult',
      'adult': 'evolved',
    }[pet.stage];
    if (nextStage == null) return 'Pet đã ở giai đoạn tối đa';

    pets[idx] = {...pets[idx], 'stage': nextStage, 'xp': 0};
    await ref.update({'pets': pets});
    return null;
  }

  // ── Pet: xóa pet ──────────────────────────────────────
  static Future<void> releasePet(String petId) async {
    if (_uid.isEmpty) return;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final pets = List<Map<String, dynamic>>.from(
        (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);
    pets.removeWhere((p) => p['id'] == petId);
    await ref.update({'pets': pets});
  }

  // ── Pet: đổi loại (legacy) ─────────────────────────────
  static Future<void> changePetType(String petType) async {
    if (_uid.isEmpty) return;
    await addPet(petType);
  }

  // ── Gacha: rút thăm pet ───────────────────────────────
  static Future<GachaResult> gachaPull({required int cost, required String currency}) async {
    if (_uid.isEmpty) return GachaResult.error('Chưa đăng nhập');
    final userRef = _db.collection('users').doc(_uid);
    final houseRef = _db.collection('houses').doc(_uid);
    GachaResult? result;
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final houseSnap = await tx.get(houseRef);
      final userData = userSnap.data() ?? {};
      final houseData = houseSnap.data() ?? {};
      final balance = (userData[currency] ?? 0).toInt();
      if (balance < cost) {
        result = GachaResult.error(currency == 'coins'
            ? 'Không đủ 🪙 (cần $cost, có $balance)'
            : 'Không đủ 💎 (cần $cost, có $balance)');
        return;
      }
      final pets = List<Map<String, dynamic>>.from(
          (houseData['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);
      if (pets.length >= kMaxPetsAbsolute) {
        result = GachaResult.full('Bạn đã có $kMaxPetsAbsolute pet! Hãy thả bớt để nhận pet mới.');
        return;
      }
      final pulled = _rollGacha();
      tx.update(userRef, {currency: balance - cost});
      final newPet = PetData.newEgg(pulled.species);
      pets.add(newPet.toMap());
      tx.update(houseRef, {'pets': pets});
      result = GachaResult.success(pulled, newPet);
    });
    return result ?? GachaResult.error('Lỗi không xác định');
  }

  static GachaRollInfo _rollGacha() {
    final rng = Random();
    final roll = rng.nextDouble() * 100;
    if (roll < 3) {
      const legendary = ['dragon', 'unicorn', 'phoenix'];
      return GachaRollInfo(species: legendary[rng.nextInt(legendary.length)], rarity: GachaRarity.legendary);
    }
    if (roll < 15) {
      const epic = ['fox', 'bear'];
      return GachaRollInfo(species: epic[rng.nextInt(epic.length)], rarity: GachaRarity.epic);
    }
    if (roll < 40) {
      const rare = ['rabbit', 'hamster', 'penguin'];
      return GachaRollInfo(species: rare[rng.nextInt(rare.length)], rarity: GachaRarity.rare);
    }
    const common = ['cat', 'dog'];
    return GachaRollInfo(species: common[rng.nextInt(common.length)], rarity: GachaRarity.common);
  }

  static Future<GachaBatchResult> gachaPull10({required int cost, required String currency}) async {
    if (_uid.isEmpty) return GachaBatchResult.error('Chưa đăng nhập');
    final userRef = _db.collection('users').doc(_uid);
    final houseRef = _db.collection('houses').doc(_uid);
    GachaBatchResult? result;
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final houseSnap = await tx.get(houseRef);
      final userData = userSnap.data() ?? {};
      final houseData = houseSnap.data() ?? {};
      final balance = (userData[currency] ?? 0).toInt();
      if (balance < cost) {
        result = GachaBatchResult.error(currency == 'coins'
            ? 'Không đủ 🪙 (cần $cost, có $balance)'
            : 'Không đủ 💎 (cần $cost, có $balance)');
        return;
      }
      final pets = List<Map<String, dynamic>>.from(
          (houseData['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);
      if (pets.length >= kMaxPetsAbsolute) {
        result = GachaBatchResult.full('Bạn đã có $kMaxPetsAbsolute pet! Hãy thả bớt để nhận pet mới.');
        return;
      }
      final rolls = <GachaRollInfo>[];
      for (int i = 0; i < 10; i++) rolls.add(_rollGacha());
      final hasRarePlus = rolls.any((r) => r.rarity.index >= GachaRarity.rare.index);
      if (!hasRarePlus) {
        const rare = ['rabbit', 'hamster', 'penguin'];
        rolls[9] = GachaRollInfo(species: rare[Random().nextInt(rare.length)], rarity: GachaRarity.rare);
      }
      final availableSlots = kMaxPetsAbsolute - pets.length;
      final toAdd = rolls.take(availableSlots).toList();
      for (final roll in toAdd) pets.add(PetData.newEgg(roll.species).toMap());
      tx.update(userRef, {currency: balance - cost});
      tx.update(houseRef, {'pets': pets});
      result = GachaBatchResult.success(rolls, toAdd.length);
    });
    return result ?? GachaBatchResult.error('Lỗi không xác định');
  }

  // ── Mời bạn bè thăm nhà ──────────────────────────────
  static Future<void> visitHouse(String ownerUid) async {
    if (_uid.isEmpty) return;
    final userDoc = await _db.collection('users').doc(_uid).get();
    final userData = userDoc.data() ?? {};

    await _db.collection('houses').doc(ownerUid).update({
      'visitors': FieldValue.arrayUnion([
        {
          'uid': _uid,
          'name': userData['displayName'] ?? 'Khách',
          'photo': userData['photoURL'] ?? '',
          'visitedAt': Timestamp.now(),
        }
      ]),
    });
  }

  // ── Decay pet stats theo thời gian ───────────────────
  static Future<void> decayPetStats() async {
    if (_uid.isEmpty) return;
    final ref = _db.collection('houses').doc(_uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final pets = List<Map<String, dynamic>>.from(
        (data['pets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);

    bool changed = false;
    for (int i = 0; i < pets.length; i++) {
      final pet = pets[i];
      if (pet['stage'] == 'egg') continue;
      final lastDecay = (pet['lastDecayAt'] as Timestamp?)?.toDate();
      if (lastDecay == null) {
        pets[i] = {...pet, 'lastDecayAt': Timestamp.now()};
        changed = true;
        continue;
      }
      final hours = DateTime.now().difference(lastDecay).inHours;
      if (hours < 1) continue;
      pets[i] = {
        ...pet,
        'hunger': (((pet['hunger'] ?? 50) as num).toInt() - hours * 5).clamp(0, 100),
        'happiness': (((pet['happiness'] ?? 50) as num).toInt() - hours * 3).clamp(0, 100),
        'lastDecayAt': Timestamp.now(),
      };
      changed = true;
    }
    if (changed) await ref.update({'pets': pets});
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class HouseData {
  final String wallpaper;
  final String floorType;
  final List<PlacedItem> placedItems;
  final List<String> ownedItems;
  final List<PetData> pets;   // up to maxPetsForHouseLevel
  final List<Map<String, dynamic>> visitors;
  final int houseLevel;       // 1-5, unlocks more pet slots

  const HouseData({
    required this.wallpaper,
    required this.floorType,
    required this.placedItems,
    required this.ownedItems,
    required this.pets,
    required this.visitors,
    this.houseLevel = 1,
  });

  // Legacy compat: first pet
  PetData get pet => pets.isNotEmpty ? pets.first : PetData.newEgg('cat').copyWith(stage: 'adult');

  int get maxPets => maxPetsForHouseLevel(houseLevel);

  factory HouseData.defaultHouse() => HouseData(
        wallpaper: 'wall_white',
        floorType: 'floor_wood',
        placedItems: [
          PlacedItem(instanceId: 'default_bed', itemId: 'bed_basic', gridX: 5, gridY: 1),
          PlacedItem(instanceId: 'default_sofa', itemId: 'sofa', gridX: 1, gridY: 2),
          PlacedItem(instanceId: 'default_plant', itemId: 'plant_big', gridX: 6, gridY: 0),
          PlacedItem(instanceId: 'default_tv', itemId: 'tv', gridX: 3, gridY: 0),
        ],
        ownedItems: ['wall_white', 'floor_wood', 'bed_basic', 'sofa', 'plant_big', 'tv'],
        pets: [
          PetData(
            id: 'default_cat',
            species: 'cat',
            stage: 'adult',
            name: 'Mèo con',
            hunger: 70,
            happiness: 80,
            level: 1,
            xp: 0,
            posX: 0.25,
            posY: 0.60,
          ),
        ],
        visitors: [],
        houseLevel: 1,
      );

  factory HouseData.fromMap(Map<String, dynamic> map) {
    // Support both old single-pet and new multi-pet format
    List<PetData> pets = [];
    if (map['pets'] != null) {
      pets = (map['pets'] as List)
          .map((e) => PetData.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else if (map['pet'] != null) {
      // Migrate old single pet
      final old = PetData.fromMap(Map<String, dynamic>.from(map['pet']));
      pets = [PetData(
        id: 'migrated_${old.species}',
        species: old.species,
        stage: 'adult',
        name: old.name,
        hunger: old.hunger,
        happiness: old.happiness,
        level: old.level,
        xp: old.xp,
        posX: 0.25,
        posY: 0.60,
      )];
    }
    if (pets.isEmpty) {
      pets = [HouseData.defaultHouse().pets.first];
    }

    return HouseData(
      wallpaper: map['wallpaper'] ?? 'wall_white',
      floorType: map['floorType'] ?? 'floor_wood',
      placedItems: (map['placedItems'] as List?)
              ?.map((e) => PlacedItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ?? [],
      ownedItems: List<String>.from(map['ownedItems'] ?? ['wall_white', 'floor_wood', 'bed_basic']),
      pets: pets,
      visitors: List<Map<String, dynamic>>.from(map['visitors'] ?? []),
      houseLevel: (map['houseLevel'] ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'wallpaper': wallpaper,
        'floorType': floorType,
        'placedItems': placedItems.map((p) => p.toMap()).toList(),
        'ownedItems': ownedItems,
        'pets': pets.map((p) => p.toMap()).toList(),
        'visitors': visitors,
        'houseLevel': houseLevel,
      };
}

class PlacedItem {
  final String instanceId;
  final String itemId;
  final int gridX;
  final int gridY;
  final int rotation; // 0, 90, 180, 270
  // Vị trí tự do (pixel fraction 0.0–1.0), dùng khi freePlace = true
  final double? fracX;
  final double? fracY;
  final bool freePlace; // true = dùng fracX/fracY thay vì grid
  final double scale;   // 0.5 – 2.0, mặc định 1.0

  const PlacedItem({
    required this.instanceId,
    required this.itemId,
    required this.gridX,
    required this.gridY,
    this.rotation = 0,
    this.fracX,
    this.fracY,
    this.freePlace = false,
    this.scale = 1.0,
  });

  factory PlacedItem.fromMap(Map<String, dynamic> map) => PlacedItem(
        instanceId: map['instanceId'] ?? '',
        itemId: map['itemId'] ?? '',
        gridX: (map['gridX'] ?? 0).toInt(),
        gridY: (map['gridY'] ?? 0).toInt(),
        rotation: (map['rotation'] ?? 0).toInt(),
        fracX: (map['fracX'] as num?)?.toDouble(),
        fracY: (map['fracY'] as num?)?.toDouble(),
        freePlace: map['freePlace'] == true,
        scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toMap() => {
        'instanceId': instanceId,
        'itemId': itemId,
        'gridX': gridX,
        'gridY': gridY,
        'rotation': rotation,
        if (fracX != null) 'fracX': fracX,
        if (fracY != null) 'fracY': fracY,
        'freePlace': freePlace,
        'scale': scale,
      };

  PlacedItem copyWith({
    int? gridX,
    int? gridY,
    int? rotation,
    double? fracX,
    double? fracY,
    bool? freePlace,
    double? scale,
  }) =>
      PlacedItem(
        instanceId: instanceId,
        itemId: itemId,
        gridX: gridX ?? this.gridX,
        gridY: gridY ?? this.gridY,
        rotation: rotation ?? this.rotation,
        fracX: fracX ?? this.fracX,
        fracY: fracY ?? this.fracY,
        freePlace: freePlace ?? this.freePlace,
        scale: scale ?? this.scale,
      );
}

class PetData {
  final String id;          // unique pet instance id
  final String species;     // 'cat','dog','rabbit','hamster','dragon','fox','bear','penguin','unicorn','phoenix'
  final String stage;       // 'egg' | 'baby' | 'teen' | 'adult' | 'evolved'
  final String name;
  final int hunger;
  final int happiness;
  final int level;
  final int xp;
  final DateTime? hatchAt;  // when egg hatches (null if not egg)
  final double posX;        // position in room (0.0–1.0)
  final double posY;

  const PetData({
    required this.id,
    required this.species,
    required this.stage,
    required this.name,
    required this.hunger,
    required this.happiness,
    required this.level,
    required this.xp,
    this.hatchAt,
    this.posX = 0.3,
    this.posY = 0.6,
  });

  factory PetData.newEgg(String species) {
    final info = kPetSpecies[species] ?? kPetSpecies['cat']!;
    return PetData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      species: species,
      stage: 'egg',
      name: info.defaultName,
      hunger: 80,
      happiness: 80,
      level: 1,
      xp: 0,
      hatchAt: DateTime.now().add(const Duration(seconds: 10)),
      posX: 0.3 + (DateTime.now().millisecond % 40) / 100,
      posY: 0.55 + (DateTime.now().millisecond % 20) / 100,
    );
  }

  factory PetData.fromMap(Map<String, dynamic> map) => PetData(
        id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        species: map['species'] ?? map['type'] ?? 'cat',
        stage: map['stage'] ?? 'adult',
        name: map['name'] ?? 'Pet',
        hunger: (map['hunger'] ?? 70).toInt(),
        happiness: (map['happiness'] ?? 80).toInt(),
        level: (map['level'] ?? 1).toInt(),
        xp: (map['xp'] ?? 0).toInt(),
        hatchAt: (map['hatchAt'] as Timestamp?)?.toDate(),
        posX: (map['posX'] ?? 0.3).toDouble(),
        posY: (map['posY'] ?? 0.6).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'species': species,
        'stage': stage,
        'name': name,
        'hunger': hunger,
        'happiness': happiness,
        'level': level,
        'xp': xp,
        'hatchAt': hatchAt != null ? Timestamp.fromDate(hatchAt!) : null,
        'posX': posX,
        'posY': posY,
      };

  PetData copyWith({
    String? stage, String? name, int? hunger, int? happiness,
    int? level, int? xp, DateTime? hatchAt, double? posX, double? posY,
  }) => PetData(
        id: id, species: species,
        stage: stage ?? this.stage,
        name: name ?? this.name,
        hunger: hunger ?? this.hunger,
        happiness: happiness ?? this.happiness,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        hatchAt: hatchAt ?? this.hatchAt,
        posX: posX ?? this.posX,
        posY: posY ?? this.posY,
      );

  bool get isEgg => stage == 'egg';
  bool get isHatched => !isEgg;
  bool get canEvolve => level >= _evolveLevel && stage != 'evolved';

  int get _evolveLevel {
    switch (stage) {
      case 'baby': return 5;
      case 'teen': return 10;
      case 'adult': return 20;
      default: return 999;
    }
  }

  String get emoji {
    final info = kPetSpecies[species] ?? kPetSpecies['cat']!;
    switch (stage) {
      case 'egg': return info.eggEmoji;
      case 'baby': return info.babyEmoji;
      case 'teen': return info.teenEmoji;
      case 'evolved': return info.evolvedEmoji;
      default: return info.adultEmoji;
    }
  }

  String get stageName {
    switch (stage) {
      case 'egg': return 'Trứng';
      case 'baby': return 'Sơ sinh';
      case 'teen': return 'Thiếu niên';
      case 'adult': return 'Trưởng thành';
      case 'evolved': return '✨ Tiến hóa';
      default: return stage;
    }
  }

  String get moodEmoji {
    if (isEgg) return '🥚';
    if (happiness >= 80) return '❤️';
    if (happiness >= 50) return '🩷';
    if (happiness >= 30) return '💔';
    return '😢';
  }

  String get hungerStatus {
    if (hunger >= 80) return 'No bụng';
    if (hunger >= 50) return 'Bình thường';
    if (hunger >= 20) return 'Hơi đói';
    return 'Rất đói!';
  }

  // Legacy compat
  String get type => species;
}

// ─── Pet Species Catalogue ────────────────────────────────────────────────────

class PetSpeciesInfo {
  final String species;
  final String displayName;
  final String defaultName;
  final String eggEmoji;
  final String babyEmoji;
  final String teenEmoji;
  final String adultEmoji;
  final String evolvedEmoji;
  final int coinCost;
  final String description;
  final Color color;

  const PetSpeciesInfo({
    required this.species,
    required this.displayName,
    required this.defaultName,
    required this.eggEmoji,
    required this.babyEmoji,
    required this.teenEmoji,
    required this.adultEmoji,
    required this.evolvedEmoji,
    required this.coinCost,
    required this.description,
    required this.color,
  });
}

const kPetSpecies = <String, PetSpeciesInfo>{
  'cat': PetSpeciesInfo(
    species: 'cat', displayName: 'Mèo', defaultName: 'Mèo con',
    eggEmoji: '🥚', babyEmoji: '🐱', teenEmoji: '🐈', adultEmoji: '🐱', evolvedEmoji: '🦁',
    coinCost: 0, description: 'Mèo dễ thương, thích được vuốt ve',
    color: Color(0xFFFFBE0B),
  ),
  'dog': PetSpeciesInfo(
    species: 'dog', displayName: 'Chó', defaultName: 'Cún con',
    eggEmoji: '🥚', babyEmoji: '🐶', teenEmoji: '🐕', adultEmoji: '🐶', evolvedEmoji: '🐺',
    coinCost: 100, description: 'Trung thành, thích chạy nhảy',
    color: Color(0xFFFF9F1C),
  ),
  'rabbit': PetSpeciesInfo(
    species: 'rabbit', displayName: 'Thỏ', defaultName: 'Thỏ bông',
    eggEmoji: '🥚', babyEmoji: '🐰', teenEmoji: '🐇', adultEmoji: '🐰', evolvedEmoji: '🦊',
    coinCost: 80, description: 'Nhút nhát nhưng rất dễ thương',
    color: Color(0xFFFF6B9D),
  ),
  'hamster': PetSpeciesInfo(
    species: 'hamster', displayName: 'Hamster', defaultName: 'Hamster nhỏ',
    eggEmoji: '🥚', babyEmoji: '🐹', teenEmoji: '🐭', adultEmoji: '🐹', evolvedEmoji: '🐿️',
    coinCost: 60, description: 'Hoạt động về đêm, thích chạy bánh xe',
    color: Color(0xFF8B6914),
  ),
  'dragon': PetSpeciesInfo(
    species: 'dragon', displayName: 'Rồng', defaultName: 'Rồng con',
    eggEmoji: '🔮', babyEmoji: '🐲', teenEmoji: '🐉', adultEmoji: '🐉', evolvedEmoji: '🔥',
    coinCost: 500, description: 'Huyền thoại! Rất hiếm và mạnh mẽ',
    color: Color(0xFF667eea),
  ),
  'fox': PetSpeciesInfo(
    species: 'fox', displayName: 'Cáo', defaultName: 'Cáo nhỏ',
    eggEmoji: '🥚', babyEmoji: '🦊', teenEmoji: '🦊', adultEmoji: '🦊', evolvedEmoji: '🌟',
    coinCost: 200, description: 'Thông minh và tinh nghịch',
    color: Color(0xFFFF6B35),
  ),
  'bear': PetSpeciesInfo(
    species: 'bear', displayName: 'Gấu', defaultName: 'Gấu bông',
    eggEmoji: '🥚', babyEmoji: '🐻', teenEmoji: '🐻', adultEmoji: '🐻', evolvedEmoji: '🐼',
    coinCost: 150, description: 'Hiền lành, thích ngủ và ăn mật',
    color: Color(0xFF8B4513),
  ),
  'penguin': PetSpeciesInfo(
    species: 'penguin', displayName: 'Chim cánh cụt', defaultName: 'Cánh cụt',
    eggEmoji: '🥚', babyEmoji: '🐧', teenEmoji: '🐧', adultEmoji: '🐧', evolvedEmoji: '❄️',
    coinCost: 180, description: 'Đáng yêu, thích bơi lội',
    color: Color(0xFF00B4D8),
  ),
  'unicorn': PetSpeciesInfo(
    species: 'unicorn', displayName: 'Kỳ lân', defaultName: 'Kỳ lân',
    eggEmoji: '🌈', babyEmoji: '🦄', teenEmoji: '🦄', adultEmoji: '🦄', evolvedEmoji: '✨',
    coinCost: 800, description: 'Huyền thoại! Mang lại may mắn',
    color: Color(0xFFC44DFF),
  ),
  'phoenix': PetSpeciesInfo(
    species: 'phoenix', displayName: 'Phượng hoàng', defaultName: 'Phượng hoàng',
    eggEmoji: '🔥', babyEmoji: '🐦', teenEmoji: '🦅', adultEmoji: '🦅', evolvedEmoji: '🌟',
    coinCost: 1000, description: 'Tối thượng! Tái sinh từ tro tàn',
    color: Color(0xFFFF4757),
  ),
};

// ─── House Level ──────────────────────────────────────────────────────────────

/// Giới hạn tối đa tuyệt đối là 5 pet, bất kể house level
const int kMaxPetsAbsolute = 5;

int maxPetsForHouseLevel(int houseLevel) {
  if (houseLevel >= 5) return 5;
  if (houseLevel >= 4) return 4;
  if (houseLevel >= 3) return 3;
  if (houseLevel >= 2) return 2;
  return 1;
}

// ─── Shop Items ───────────────────────────────────────────────────────────────

class HouseItem {
  final String id;
  final String name;
  final String emoji;
  final String category; // 'wallpaper', 'floor', 'furniture', 'decoration', 'pet'
  final int price;
  final String description;
  final bool isDefault;

  const HouseItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.price,
    required this.description,
    this.isDefault = false,
  });
}

// ── Catalogue đầy đủ ──────────────────────────────────────────────────────────
class HouseItemCatalogue {
  static const List<HouseItem> all = [
    // ── Wallpapers ──────────────────────────────────────
    HouseItem(id: 'wall_white',    name: 'Tường trắng',    emoji: '🟫', category: 'wallpaper', price: 0,   description: 'Tường trắng cơ bản', isDefault: true),
    HouseItem(id: 'wall_pink',     name: 'Tường hồng',     emoji: '🌸', category: 'wallpaper', price: 50,  description: 'Tường màu hồng dễ thương'),
    HouseItem(id: 'wall_blue',     name: 'Tường xanh',     emoji: '💙', category: 'wallpaper', price: 50,  description: 'Tường màu xanh dịu mát'),
    HouseItem(id: 'wall_wood',     name: 'Tường gỗ',       emoji: '🪵', category: 'wallpaper', price: 80,  description: 'Tường ốp gỗ ấm áp'),
    HouseItem(id: 'wall_brick',    name: 'Tường gạch',     emoji: '🧱', category: 'wallpaper', price: 100, description: 'Tường gạch vintage'),
    HouseItem(id: 'wall_floral',   name: 'Hoa văn',        emoji: '🌺', category: 'wallpaper', price: 120, description: 'Giấy dán tường hoa văn'),
    HouseItem(id: 'wall_stars',    name: 'Ngôi sao',       emoji: '⭐', category: 'wallpaper', price: 150, description: 'Tường ngôi sao lung linh'),
    HouseItem(id: 'wall_green',    name: 'Tường xanh lá',  emoji: '🌿', category: 'wallpaper', price: 70,  description: 'Tường xanh lá tươi mát'),
    HouseItem(id: 'wall_lavender', name: 'Tường tím',      emoji: '💜', category: 'wallpaper', price: 90,  description: 'Tường màu lavender thơ mộng'),
    HouseItem(id: 'wall_sunset',   name: 'Hoàng hôn',      emoji: '🌅', category: 'wallpaper', price: 180, description: 'Tường gradient hoàng hôn'),
    HouseItem(id: 'wall_ocean',    name: 'Đại dương',      emoji: '🌊', category: 'wallpaper', price: 160, description: 'Tường sóng biển xanh'),
    HouseItem(id: 'wall_candy',    name: 'Kẹo ngọt',       emoji: '🍬', category: 'wallpaper', price: 130, description: 'Tường kẹo ngọt pastel'),

    // ── Floors ──────────────────────────────────────────
    HouseItem(id: 'floor_tile_blue', name: 'Gạch xanh',   emoji: '🔷', category: 'floor', price: 0,   description: 'Sàn gạch xanh cơ bản', isDefault: true),
    HouseItem(id: 'floor_wood',      name: 'Sàn gỗ',      emoji: '🪵', category: 'floor', price: 60,  description: 'Sàn gỗ ấm áp'),
    HouseItem(id: 'floor_marble',    name: 'Đá cẩm thạch',emoji: '⬜', category: 'floor', price: 100, description: 'Sàn đá cẩm thạch sang trọng'),
    HouseItem(id: 'floor_carpet',    name: 'Thảm đỏ',     emoji: '🟥', category: 'floor', price: 80,  description: 'Thảm trải sàn mềm mại'),
    HouseItem(id: 'floor_grass',     name: 'Cỏ xanh',     emoji: '🌿', category: 'floor', price: 90,  description: 'Sàn cỏ nhân tạo'),
    HouseItem(id: 'floor_checker',   name: 'Ô cờ',        emoji: '♟️', category: 'floor', price: 110, description: 'Sàn ô cờ đen trắng'),
    HouseItem(id: 'floor_pink',      name: 'Thảm hồng',   emoji: '🩷', category: 'floor', price: 85,  description: 'Thảm hồng dễ thương'),
    HouseItem(id: 'floor_cloud',     name: 'Mây trắng',   emoji: '☁️', category: 'floor', price: 140, description: 'Sàn mây trắng mềm mại'),

    // ── Furniture ───────────────────────────────────────
    HouseItem(id: 'bed_basic',     name: 'Giường cơ bản', emoji: '🛏️', category: 'furniture', price: 0,   description: 'Giường ngủ đơn giản', isDefault: true),
    HouseItem(id: 'bed_fancy',     name: 'Giường sang',   emoji: '🛏️', category: 'furniture', price: 150, description: 'Giường ngủ sang trọng'),
    HouseItem(id: 'sofa',          name: 'Ghế sofa',      emoji: '🛋️', category: 'furniture', price: 120, description: 'Ghế sofa thoải mái'),
    HouseItem(id: 'table_coffee',  name: 'Bàn trà',       emoji: '🪑', category: 'furniture', price: 80,  description: 'Bàn trà nhỏ xinh'),
    HouseItem(id: 'bookshelf',     name: 'Kệ sách',       emoji: '📚', category: 'furniture', price: 100, description: 'Kệ sách học tập'),
    HouseItem(id: 'desk',          name: 'Bàn học',       emoji: '🖥️', category: 'furniture', price: 130, description: 'Bàn học tiếng Anh'),
    HouseItem(id: 'wardrobe',      name: 'Tủ quần áo',    emoji: '🚪', category: 'furniture', price: 110, description: 'Tủ quần áo gỗ'),
    HouseItem(id: 'tv',            name: 'TV',             emoji: '📺', category: 'furniture', price: 200, description: 'Tivi màn hình phẳng'),
    HouseItem(id: 'piano',         name: 'Đàn piano',     emoji: '🎹', category: 'furniture', price: 300, description: 'Đàn piano mini'),
    HouseItem(id: 'bathtub',       name: 'Bồn tắm',       emoji: '🛁', category: 'furniture', price: 180, description: 'Bồn tắm thư giãn'),
    HouseItem(id: 'fridge',        name: 'Tủ lạnh',       emoji: '🧊', category: 'furniture', price: 160, description: 'Tủ lạnh mini'),
    HouseItem(id: 'couch',         name: 'Ghế bành',      emoji: '🪑', category: 'furniture', price: 95,  description: 'Ghế bành êm ái'),
    HouseItem(id: 'dining_table',  name: 'Bàn ăn',        emoji: '🍽️', category: 'furniture', price: 140, description: 'Bàn ăn gia đình'),
    HouseItem(id: 'mirror',        name: 'Gương',         emoji: '🪞', category: 'furniture', price: 75,  description: 'Gương toàn thân'),
    HouseItem(id: 'cat_tree',      name: 'Cây leo mèo',   emoji: '🐱', category: 'furniture', price: 120, description: 'Cây leo cho mèo'),

    // ── Decorations ─────────────────────────────────────
    HouseItem(id: 'plant_small',   name: 'Cây nhỏ',       emoji: '🌱', category: 'decoration', price: 30,  description: 'Cây cảnh nhỏ'),
    HouseItem(id: 'plant_big',     name: 'Cây lớn',       emoji: '🌿', category: 'decoration', price: 60,  description: 'Cây cảnh lớn'),
    HouseItem(id: 'lamp',          name: 'Đèn',           emoji: '💡', category: 'decoration', price: 50,  description: 'Đèn trang trí'),
    HouseItem(id: 'painting',      name: 'Tranh',         emoji: '🖼️', category: 'decoration', price: 70,  description: 'Tranh treo tường'),
    HouseItem(id: 'globe',         name: 'Quả địa cầu',   emoji: '🌍', category: 'decoration', price: 90,  description: 'Quả địa cầu học địa lý'),
    HouseItem(id: 'clock',         name: 'Đồng hồ',       emoji: '🕐', category: 'decoration', price: 60,  description: 'Đồng hồ treo tường'),
    HouseItem(id: 'rug',           name: 'Thảm tròn',     emoji: '⭕', category: 'decoration', price: 80,  description: 'Thảm tròn trang trí'),
    HouseItem(id: 'fairy_lights',  name: 'Đèn dây',       emoji: '✨', category: 'decoration', price: 100, description: 'Đèn dây lung linh'),
    HouseItem(id: 'radio',         name: 'Radio',         emoji: '📻', category: 'decoration', price: 70,  description: 'Radio cổ điển'),
    HouseItem(id: 'flowers',       name: 'Bình hoa',      emoji: '💐', category: 'decoration', price: 40,  description: 'Bình hoa tươi'),
    HouseItem(id: 'fireplace',     name: 'Lò sưởi',       emoji: '🔥', category: 'decoration', price: 250, description: 'Lò sưởi đá ấm áp'),
    HouseItem(id: 'candle',        name: 'Nến thơm',      emoji: '🕯️', category: 'decoration', price: 35,  description: 'Nến thơm lãng mạn'),
    HouseItem(id: 'trophy',        name: 'Cúp',           emoji: '🏆', category: 'decoration', price: 120, description: 'Cúp thành tích học tập'),
    HouseItem(id: 'aquarium',      name: 'Bể cá',         emoji: '🐠', category: 'decoration', price: 200, description: 'Bể cá mini'),
    HouseItem(id: 'cactus',        name: 'Xương rồng',    emoji: '🌵', category: 'decoration', price: 45,  description: 'Xương rồng mini'),
    HouseItem(id: 'balloon',       name: 'Bóng bay',      emoji: '🎈', category: 'decoration', price: 25,  description: 'Bóng bay vui nhộn'),
    HouseItem(id: 'teddy',         name: 'Gấu bông',      emoji: '🧸', category: 'decoration', price: 55,  description: 'Gấu bông dễ thương'),
    HouseItem(id: 'star_lamp',     name: 'Đèn sao',       emoji: '⭐', category: 'decoration', price: 85,  description: 'Đèn ngôi sao lung linh'),
    HouseItem(id: 'rainbow',       name: 'Cầu vồng',      emoji: '🌈', category: 'decoration', price: 150, description: 'Tranh cầu vồng'),

    // ── Pets ────────────────────────────────────────────
    HouseItem(id: 'pet_dog',       name: 'Chó cún',       emoji: '🐶', category: 'pet', price: 200, description: 'Chó cún đáng yêu'),
    HouseItem(id: 'pet_rabbit',    name: 'Thỏ bông',      emoji: '🐰', category: 'pet', price: 180, description: 'Thỏ bông mềm mại'),
    HouseItem(id: 'pet_hamster',   name: 'Chuột hamster', emoji: '🐹', category: 'pet', price: 150, description: 'Hamster nhỏ xinh'),
  ];

  static List<HouseItem> byCategory(String cat) =>
      all.where((i) => i.category == cat).toList();

  static HouseItem? byId(String id) {
    try { return all.firstWhere((i) => i.id == id); }
    catch (_) { return null; }
  }
}

// ─── Result classes ───────────────────────────────────────────────────────────

class ShopResult {
  final bool success;
  final String message;
  const ShopResult._({required this.success, required this.message});
  factory ShopResult.success(String msg) => ShopResult._(success: true, message: msg);
  factory ShopResult.error(String msg) => ShopResult._(success: false, message: msg);
}

class PetFeedResult {
  final bool success;
  final String message;
  final int newHunger;
  final int newHappiness;
  const PetFeedResult({
    required this.success,
    required this.message,
    this.newHunger = 0,
    this.newHappiness = 0,
  });
}

// ─── Gacha Models ─────────────────────────────────────────────────────────────

enum GachaRarity { common, rare, epic, legendary }

extension GachaRarityExt on GachaRarity {
  String get label {
    switch (this) {
      case GachaRarity.common: return 'Thường';
      case GachaRarity.rare: return 'Hiếm';
      case GachaRarity.epic: return 'Sử thi';
      case GachaRarity.legendary: return 'Huyền thoại';
    }
  }

  Color get color {
    switch (this) {
      case GachaRarity.common: return const Color(0xFF9E9E9E);
      case GachaRarity.rare: return const Color(0xFF2196F3);
      case GachaRarity.epic: return const Color(0xFF9C27B0);
      case GachaRarity.legendary: return const Color(0xFFFF9800);
    }
  }

  String get glowEmoji {
    switch (this) {
      case GachaRarity.common: return '⚪';
      case GachaRarity.rare: return '🔵';
      case GachaRarity.epic: return '🟣';
      case GachaRarity.legendary: return '🌟';
    }
  }
}

class GachaRollInfo {
  final String species;
  final GachaRarity rarity;
  const GachaRollInfo({required this.species, required this.rarity});
}

class GachaResult {
  final bool success;
  final bool isFull;
  final String? errorMessage;
  final GachaRollInfo? roll;
  final PetData? newPet;

  const GachaResult._({
    required this.success,
    this.isFull = false,
    this.errorMessage,
    this.roll,
    this.newPet,
  });

  factory GachaResult.success(GachaRollInfo roll, PetData pet) =>
      GachaResult._(success: true, roll: roll, newPet: pet);
  factory GachaResult.error(String msg) =>
      GachaResult._(success: false, errorMessage: msg);
  factory GachaResult.full(String msg) =>
      GachaResult._(success: false, isFull: true, errorMessage: msg);
}

class GachaBatchResult {
  final bool success;
  final bool isFull;
  final String? errorMessage;
  final List<GachaRollInfo> rolls;
  final int addedCount;

  const GachaBatchResult._({
    required this.success,
    this.isFull = false,
    this.errorMessage,
    this.rolls = const [],
    this.addedCount = 0,
  });

  factory GachaBatchResult.success(List<GachaRollInfo> rolls, int added) =>
      GachaBatchResult._(success: true, rolls: rolls, addedCount: added);
  factory GachaBatchResult.error(String msg) =>
      GachaBatchResult._(success: false, errorMessage: msg);
  factory GachaBatchResult.full(String msg) =>
      GachaBatchResult._(success: false, isFull: true, errorMessage: msg);
}
