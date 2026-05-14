import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// FriendService — quản lý kết bạn
///
/// Firestore structure:
/// friend_requests/{requestId}
///   - fromUid, toUid, status ('pending'|'accepted'|'declined'), createdAt
///
/// friendships/{friendshipId}  (friendshipId = sorted uid1_uid2)
///   - uids: [uid1, uid2], createdAt
///   - users/{uid1}: {displayName, photoURL, level, streak}
///   - users/{uid2}: {displayName, photoURL, level, streak}
///
/// users/{uid}.userCode — mã 6 ký tự duy nhất, ví dụ: "AB12CD"
class FriendService {
  static final _db = FirebaseFirestore.instance;
  static String get _me => FirebaseAuth.instance.currentUser!.uid;

  // ── ID friendship chuẩn hoá (uid nhỏ hơn đứng trước) ─
  static String _fid(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // ── Sinh mã user ngẫu nhiên 6 ký tự (chữ hoa + số) ──
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ 0/O, 1/I dễ nhầm
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Đảm bảo user có userCode, tạo nếu chưa có ────────
  static Future<String> ensureUserCode() async {
    final me = _me;
    final doc = await _db.collection('users').doc(me).get();
    final data = doc.data() ?? {};

    if (data['userCode'] != null && (data['userCode'] as String).isNotEmpty) {
      return data['userCode'] as String;
    }

    // Sinh mã mới, đảm bảo không trùng
    String code;
    bool exists;
    do {
      code = _generateCode();
      final snap = await _db
          .collection('users')
          .where('userCode', isEqualTo: code)
          .limit(1)
          .get();
      exists = snap.docs.isNotEmpty;
    } while (exists);

    await _db.collection('users').doc(me).update({'userCode': code});
    return code;
  }

  // ── Lấy userCode của user hiện tại (stream) ──────────
  static Stream<String> myUserCodeStream() {
    return _db
        .collection('users')
        .doc(_me)
        .snapshots()
        .map((doc) => (doc.data()?['userCode'] ?? '') as String);
  }

  // ── Tìm kiếm user theo tên hoặc #mã ──────────────────
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final raw = query.trim();

    final seen = <String>{};
    final results = <Map<String, dynamic>>[];

    // Nếu bắt đầu bằng '#' → tìm chính xác theo userCode
    if (raw.startsWith('#')) {
      final code = raw.substring(1).toUpperCase().trim();
      if (code.isNotEmpty) {
        final byCode = await _db
            .collection('users')
            .where('userCode', isEqualTo: code)
            .limit(5)
            .get();
        for (final doc in byCode.docs) {
          if (doc.id == _me) continue;
          seen.add(doc.id);
          results.add({...doc.data(), 'uid': doc.id});
        }
      }
      return results;
    }

    final q = raw.toLowerCase();

    // Tìm theo displayName (prefix search)
    final byName = await _db
        .collection('users')
        .where('searchName', isGreaterThanOrEqualTo: q)
        .where('searchName', isLessThan: '${q}z')
        .limit(20)
        .get();

    // Tìm theo userCode chính xác (không cần #)
    final byCode = await _db
        .collection('users')
        .where('userCode', isEqualTo: raw.toUpperCase())
        .limit(5)
        .get();

    // Tìm theo email chính xác
    final byEmail = await _db
        .collection('users')
        .where('email', isEqualTo: raw)
        .limit(5)
        .get();

    for (final doc in [...byName.docs, ...byCode.docs, ...byEmail.docs]) {
      if (doc.id == _me) continue;
      if (seen.contains(doc.id)) continue;
      seen.add(doc.id);
      results.add({...doc.data(), 'uid': doc.id});
    }

    return results;
  }

  // ── Gửi lời mời kết bạn ──────────────────────────────
  static Future<FriendRequestResult> sendRequest(String toUid) async {
    if (toUid == _me) {
      return FriendRequestResult.error('Không thể kết bạn với chính mình');
    }

    // Kiểm tra đã là bạn chưa
    final fid = _fid(_me, toUid);
    final existing = await _db.collection('friendships').doc(fid).get();
    if (existing.exists) return FriendRequestResult.error('Đã là bạn bè rồi');

    // Kiểm tra đã có request pending chưa
    final pending = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: _me)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (pending.docs.isNotEmpty) {
      return FriendRequestResult.error('Đã gửi lời mời rồi');
    }

    // Kiểm tra người kia đã gửi cho mình chưa
    final reverse = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: toUid)
        .where('toUid', isEqualTo: _me)
        .where('status', isEqualTo: 'pending')
        .get();
    if (reverse.docs.isNotEmpty) {
      // Tự động chấp nhận
      await acceptRequest(reverse.docs.first.id);
      return FriendRequestResult.accepted('Đã chấp nhận lời mời của họ!');
    }

    // Lấy thông tin người gửi
    final myDoc = await _db.collection('users').doc(_me).get();
    final myData = myDoc.data() ?? {};

    await _db.collection('friend_requests').add({
      'fromUid': _me,
      'toUid': toUid,
      'status': 'pending',
      'fromName': myData['displayName'] ?? '',
      'fromPhoto': myData['photoURL'] ?? '',
      'fromLevel': myData['level'] ?? 'A1',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return FriendRequestResult.sent('Đã gửi lời mời kết bạn!');
  }

  // ── Chấp nhận lời mời ────────────────────────────────
  static Future<void> acceptRequest(String requestId) async {
    final reqDoc = await _db.collection('friend_requests').doc(requestId).get();
    if (!reqDoc.exists) return;

    final data = reqDoc.data()!;
    final fromUid = data['fromUid'] as String;
    final toUid = data['toUid'] as String;

    // Lấy thông tin cả 2 user
    final results = await Future.wait([
      _db.collection('users').doc(fromUid).get(),
      _db.collection('users').doc(toUid).get(),
    ]);
    final fromData = results[0].data() ?? {};
    final toData = results[1].data() ?? {};

    final fid = _fid(fromUid, toUid);
    final batch = _db.batch();

    // Tạo friendship
    batch.set(_db.collection('friendships').doc(fid), {
      'uids': [fromUid, toUid],
      'createdAt': FieldValue.serverTimestamp(),
      fromUid: {
        'displayName': fromData['displayName'] ?? '',
        'photoURL': fromData['photoURL'] ?? '',
        'level': fromData['level'] ?? 'A1',
        'streak': fromData['streak'] ?? 0,
      },
      toUid: {
        'displayName': toData['displayName'] ?? '',
        'photoURL': toData['photoURL'] ?? '',
        'level': toData['level'] ?? 'A1',
        'streak': toData['streak'] ?? 0,
      },
    });

    // Cập nhật request
    batch.update(_db.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Tạo conversation
    batch.set(_db.collection('conversations').doc(fid), {
      'participants': [fromUid, toUid],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderUid': '',
      'unread': {fromUid: 0, toUid: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Từ chối lời mời ──────────────────────────────────
  static Future<void> declineRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Huỷ kết bạn ──────────────────────────────────────
  static Future<void> unfriend(String friendUid) async {
    final fid = _fid(_me, friendUid);
    final batch = _db.batch();
    batch.delete(_db.collection('friendships').doc(fid));
    // Giữ conversation nhưng đánh dấu
    batch.update(_db.collection('conversations').doc(fid), {
      'isFriendship': false,
    });
    await batch.commit();
  }

  // ── Stream danh sách bạn bè ───────────────────────────
  static Stream<List<FriendModel>> friendsStream() {
    final me = _me;
    return _db
        .collection('friendships')
        .where('uids', arrayContains: me)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final uids = List<String>.from(data['uids'] ?? []);
              final friendUid = uids.firstWhere((u) => u != me, orElse: () => '');
              if (friendUid.isEmpty) return null;
              final friendData = data[friendUid] as Map<String, dynamic>? ?? {};
              return FriendModel(
                uid: friendUid,
                friendshipId: doc.id,
                displayName: friendData['displayName'] ?? '',
                photoURL: friendData['photoURL'] ?? '',
                level: friendData['level'] ?? 'A1',
                streak: (friendData['streak'] ?? 0).toInt(),
                createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              );
            })
            .whereType<FriendModel>()
            .toList());
  }

  // ── Stream lời mời đến ────────────────────────────────
  // Không dùng orderBy để tránh cần composite index
  static Stream<List<FriendRequestModel>> incomingRequestsStream() {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: _me)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => FriendRequestModel.fromDoc(doc))
              .toList();
          // Sort client-side
          list.sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));
          return list;
        });
  }

  // ── Đếm lời mời chưa xử lý ───────────────────────────
  static Stream<int> pendingRequestCountStream() {
    return incomingRequestsStream().map((list) => list.length);
  }

  // ── Kiểm tra trạng thái với 1 user ───────────────────
  static Future<FriendStatus> getStatusWith(String otherUid) async {
    final me = _me;
    final fid = _fid(me, otherUid);

    // Đã là bạn?
    final friendship = await _db.collection('friendships').doc(fid).get();
    if (friendship.exists) return FriendStatus.friends;

    // Đã gửi request?
    final sent = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: me)
        .where('toUid', isEqualTo: otherUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sent.docs.isNotEmpty) return FriendStatus.requestSent;

    // Nhận request?
    final received = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: otherUid)
        .where('toUid', isEqualTo: me)
        .where('status', isEqualTo: 'pending')
        .get();
    if (received.docs.isNotEmpty) return FriendStatus.requestReceived;

    return FriendStatus.none;
  }

  // ── Đảm bảo user có searchName field ─────────────────
  static Future<void> ensureSearchable() async {
    final me = _me;
    final doc = await _db.collection('users').doc(me).get();
    final data = doc.data() ?? {};

    final updates = <String, dynamic>{};

    if (!data.containsKey('searchName')) {
      final name = (data['displayName'] ?? '').toString().toLowerCase();
      updates['searchName'] = name;
    }

    // Đồng thời đảm bảo có userCode
    if (!data.containsKey('userCode') ||
        (data['userCode'] as String? ?? '').isEmpty) {
      String code;
      bool exists;
      do {
        code = _generateCode();
        final snap = await _db
            .collection('users')
            .where('userCode', isEqualTo: code)
            .limit(1)
            .get();
        exists = snap.docs.isNotEmpty;
      } while (exists);
      updates['userCode'] = code;
    }

    if (updates.isNotEmpty) {
      await _db.collection('users').doc(me).update(updates);
    }
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class FriendModel {
  final String uid;
  final String friendshipId;
  final String displayName;
  final String photoURL;
  final String level;
  final int streak;
  final DateTime? createdAt;

  const FriendModel({
    required this.uid,
    required this.friendshipId,
    required this.displayName,
    required this.photoURL,
    required this.level,
    required this.streak,
    this.createdAt,
  });
}

class FriendRequestModel {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String fromPhoto;
  final String fromLevel;
  final DateTime? createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.fromPhoto,
    required this.fromLevel,
    this.createdAt,
  });

  factory FriendRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FriendRequestModel(
      id: doc.id,
      fromUid: d['fromUid'] ?? '',
      toUid: d['toUid'] ?? '',
      fromName: d['fromName'] ?? '',
      fromPhoto: d['fromPhoto'] ?? '',
      fromLevel: d['fromLevel'] ?? 'A1',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

enum FriendStatus { none, requestSent, requestReceived, friends }

class FriendRequestResult {
  final bool success;
  final String message;
  final FriendRequestType type;

  const FriendRequestResult._({
    required this.success,
    required this.message,
    required this.type,
  });

  factory FriendRequestResult.sent(String msg) =>
      FriendRequestResult._(success: true, message: msg, type: FriendRequestType.sent);
  factory FriendRequestResult.accepted(String msg) =>
      FriendRequestResult._(success: true, message: msg, type: FriendRequestType.accepted);
  factory FriendRequestResult.error(String msg) =>
      FriendRequestResult._(success: false, message: msg, type: FriendRequestType.error);
}

enum FriendRequestType { sent, accepted, error }
