import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'farm_service.dart';

/// MarketService — chợ buôn bán giữa người dùng
///
/// Firestore:
/// market_listings/{listingId}
///   - sellerUid, sellerName, sellerPhoto
///   - itemType, itemEmoji, itemName
///   - quantity, pricePerUnit, totalPrice
///   - status: 'active' | 'sold' | 'cancelled'
///   - createdAt, soldAt, buyerUid
///
/// market_transactions/{txId}
///   - buyerUid, sellerUid, itemType, quantity, totalPrice, createdAt

// ─── Models ───────────────────────────────────────────────────────────────────

class MarketListing {
  final String listingId;
  final String sellerUid;
  final String sellerName;
  final String sellerPhoto;
  final String itemType;
  final String itemEmoji;
  final String itemName;
  final int quantity;
  final int pricePerUnit;
  final int totalPrice;
  final String status; // 'active' | 'sold' | 'cancelled'
  final DateTime createdAt;
  final DateTime? soldAt;
  final String? buyerUid;

  const MarketListing({
    required this.listingId,
    required this.sellerUid,
    required this.sellerName,
    required this.sellerPhoto,
    required this.itemType,
    required this.itemEmoji,
    required this.itemName,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.soldAt,
    this.buyerUid,
  });

  factory MarketListing.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return MarketListing(
      listingId: doc.id,
      sellerUid: m['sellerUid'] as String? ?? '',
      sellerName: m['sellerName'] as String? ?? 'Unknown',
      sellerPhoto: m['sellerPhoto'] as String? ?? '',
      itemType: m['itemType'] as String? ?? '',
      itemEmoji: m['itemEmoji'] as String? ?? '📦',
      itemName: m['itemName'] as String? ?? '',
      quantity: (m['quantity'] ?? 0).toInt(),
      pricePerUnit: (m['pricePerUnit'] ?? 0).toInt(),
      totalPrice: (m['totalPrice'] ?? 0).toInt(),
      status: m['status'] as String? ?? 'active',
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      soldAt: m['soldAt'] != null
          ? (m['soldAt'] as Timestamp).toDate()
          : null,
      buyerUid: m['buyerUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'sellerUid': sellerUid,
    'sellerName': sellerName,
    'sellerPhoto': sellerPhoto,
    'itemType': itemType,
    'itemEmoji': itemEmoji,
    'itemName': itemName,
    'quantity': quantity,
    'pricePerUnit': pricePerUnit,
    'totalPrice': totalPrice,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'soldAt': soldAt != null ? Timestamp.fromDate(soldAt!) : null,
    'buyerUid': buyerUid,
  };
}

class MarketTransaction {
  final String txId;
  final String buyerUid;
  final String sellerUid;
  final String itemType;
  final int quantity;
  final int totalPrice;
  final DateTime createdAt;

  const MarketTransaction({
    required this.txId,
    required this.buyerUid,
    required this.sellerUid,
    required this.itemType,
    required this.quantity,
    required this.totalPrice,
    required this.createdAt,
  });

  factory MarketTransaction.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return MarketTransaction(
      txId: doc.id,
      buyerUid: m['buyerUid'] as String? ?? '',
      sellerUid: m['sellerUid'] as String? ?? '',
      itemType: m['itemType'] as String? ?? '',
      quantity: (m['quantity'] ?? 0).toInt(),
      totalPrice: (m['totalPrice'] ?? 0).toInt(),
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MarketService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static String _itemEmoji(String itemType) {
    if (kCrops.containsKey(itemType)) return kCrops[itemType]!.emoji;
    if (kFish.containsKey(itemType)) return kFish[itemType]!.emoji;
    for (final a in kAnimals.values) {
      if (a.product == itemType) return a.productEmoji;
    }
    return '📦';
  }

  static String _itemName(String itemType) {
    if (kCrops.containsKey(itemType)) return itemType;
    if (kFish.containsKey(itemType)) return itemType;
    return itemType;
  }

  // ── Đăng bán ──────────────────────────────────────────

  static Future<bool> createListing({
    required String itemType,
    required int quantity,
    required int pricePerUnit,
  }) async {
    if (_uid.isEmpty) return false;
    if (quantity <= 0 || pricePerUnit <= 0) return false;

    // Lấy thông tin user
    final userDoc = await _db.collection('users').doc(_uid).get();
    final userData = userDoc.data() ?? {};
    final sellerName = userData['displayName'] as String? ?? 'Unknown';
    final sellerPhoto = userData['photoURL'] as String? ?? '';

    // Lấy item từ kho
    final removed = await FarmService.removeFromWarehouse(itemType, quantity);
    if (!removed) return false;

    await _db.collection('market_listings').add({
      'sellerUid': _uid,
      'sellerName': sellerName,
      'sellerPhoto': sellerPhoto,
      'itemType': itemType,
      'itemEmoji': _itemEmoji(itemType),
      'itemName': _itemName(itemType),
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalPrice': quantity * pricePerUnit,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'soldAt': null,
      'buyerUid': null,
    });
    return true;
  }

  // ── Mua listing ───────────────────────────────────────

  static Future<bool> buyListing(String listingId) async {
    if (_uid.isEmpty) return false;

    final listingRef = _db.collection('market_listings').doc(listingId);
    bool success = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(listingRef);
      if (!snap.exists) return;

      final listing = MarketListing.fromDoc(snap);
      if (listing.status != 'active') return;
      if (listing.sellerUid == _uid) return; // Không tự mua

      // Kiểm tra coin người mua
      final buyerRef = _db.collection('users').doc(_uid);
      final buyerSnap = await tx.get(buyerRef);
      final buyerCoins = (buyerSnap.data()?['coins'] ?? 0).toInt();
      if (buyerCoins < listing.totalPrice) return;

      // Trừ coin người mua
      tx.update(buyerRef, {'coins': buyerCoins - listing.totalPrice});

      // Cộng coin người bán
      final sellerRef = _db.collection('users').doc(listing.sellerUid);
      tx.update(sellerRef, {
        'coins': FieldValue.increment(listing.totalPrice),
        'totalCoinsEarned': FieldValue.increment(listing.totalPrice),
      });

      // Cập nhật listing
      tx.update(listingRef, {
        'status': 'sold',
        'soldAt': FieldValue.serverTimestamp(),
        'buyerUid': _uid,
      });

      success = true;
    });

    if (success) {
      // Thêm item vào kho người mua
      final snap = await listingRef.get();
      final listing = MarketListing.fromDoc(snap);
      await FarmService.addToWarehouse(listing.itemType, listing.quantity);

      // Ghi transaction
      await _db.collection('market_transactions').add({
        'buyerUid': _uid,
        'sellerUid': listing.sellerUid,
        'itemType': listing.itemType,
        'quantity': listing.quantity,
        'totalPrice': listing.totalPrice,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return success;
  }

  // ── Huỷ listing ───────────────────────────────────────

  static Future<bool> cancelListing(String listingId) async {
    if (_uid.isEmpty) return false;

    final snap = await _db.collection('market_listings').doc(listingId).get();
    if (!snap.exists) return false;

    final listing = MarketListing.fromDoc(snap);
    if (listing.sellerUid != _uid) return false;
    if (listing.status != 'active') return false;

    // Trả lại item vào kho
    await FarmService.addToWarehouse(listing.itemType, listing.quantity);

    await _db.collection('market_listings').doc(listingId).update({
      'status': 'cancelled',
    });
    return true;
  }

  // ── Streams ───────────────────────────────────────────

  static Stream<List<MarketListing>> activeListingsStream() {
    return _db
        .collection('market_listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(MarketListing.fromDoc).toList());
  }

  static Stream<List<MarketListing>> myListingsStream() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db
        .collection('market_listings')
        .where('sellerUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(MarketListing.fromDoc).toList());
  }

  static Future<List<MarketTransaction>> getTransactionHistory() async {
    if (_uid.isEmpty) return [];
    final q = await _db
        .collection('market_transactions')
        .where(Filter.or(
          Filter('buyerUid', isEqualTo: _uid),
          Filter('sellerUid', isEqualTo: _uid),
        ))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return q.docs.map(MarketTransaction.fromDoc).toList();
  }
}
