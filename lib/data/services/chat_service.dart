import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ChatService — chat realtime 1-1 qua Firestore
///
/// Firestore structure:
/// conversations/{conversationId}  (conversationId = friendshipId = sorted uid1_uid2)
///   - participants: [uid1, uid2]
///   - lastMessage: string
///   - lastMessageAt: timestamp
///   - lastSenderUid: string
///   - unread: {uid1: 0, uid2: 3}
///
/// conversations/{conversationId}/messages/{messageId}
///   - senderUid: string
///   - text: string
///   - type: 'text' | 'image'
///   - imageUrl: string (optional)
///   - createdAt: timestamp
///   - readBy: [uid1, uid2]
class ChatService {
  static final _db = FirebaseFirestore.instance;
  static String get _me => FirebaseAuth.instance.currentUser!.uid;

  // ── ID conversation (giống friendshipId) ─────────────
  static String convId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // ── Gửi tin nhắn ─────────────────────────────────────
  static Future<void> sendMessage({
    required String toUid,
    required String text,
    String? imageUrl,
  }) async {
    final me = _me;
    final cid = convId(me, toUid);
    final type = imageUrl != null ? 'image' : 'text';
    final content = imageUrl ?? text;

    final batch = _db.batch();
    final msgRef = _db
        .collection('conversations')
        .doc(cid)
        .collection('messages')
        .doc();

    // Thêm message
    batch.set(msgRef, {
      'senderUid': me,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [me],
    });

    // Cập nhật conversation
    batch.set(
      _db.collection('conversations').doc(cid),
      {
        'participants': [me, toUid],
        'lastMessage': type == 'image' ? '📷 Hình ảnh' : content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderUid': me,
        'unread': {toUid: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ── Stream tin nhắn trong conversation ───────────────
  static Stream<List<MessageModel>> messagesStream(String otherUid) {
    final cid = convId(_me, otherUid);
    return _db
        .collection('conversations')
        .doc(cid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }

  // ── Stream danh sách conversations ───────────────────
  // Không dùng orderBy để tránh cần composite index — sort client-side
  static Stream<List<ConversationModel>> conversationsStream() {
    final me = _me;
    if (me.isEmpty) return Stream.value([]);
    return _db
        .collection('conversations')
        .where('participants', arrayContains: me)
        .snapshots()
        .asyncMap((snap) async {
      final list = <ConversationModel>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUid =
            participants.firstWhere((u) => u != me, orElse: () => '');
        if (otherUid.isEmpty) continue;

        // Lấy thông tin người kia
        final otherDoc =
            await _db.collection('users').doc(otherUid).get();
        final otherData = otherDoc.data() ?? {};

        final unreadMap = data['unread'] as Map<String, dynamic>? ?? {};
        final unread = (unreadMap[me] ?? 0).toInt();

        list.add(ConversationModel(
          id: doc.id,
          otherUid: otherUid,
          otherName: otherData['displayName'] ?? 'Người dùng',
          otherPhoto: otherData['photoURL'] ?? '',
          otherLevel: otherData['level'] ?? 'A1',
          lastMessage: data['lastMessage'] ?? '',
          lastMessageAt:
              (data['lastMessageAt'] as Timestamp?)?.toDate(),
          lastSenderUid: data['lastSenderUid'] ?? '',
          unreadCount: unread,
        ));
      }
      // Sort client-side by lastMessageAt descending
      list.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
          .compareTo(a.lastMessageAt ?? DateTime(0)));
      return list;
    });
  }

  // ── Đánh dấu đã đọc ──────────────────────────────────
  static Future<void> markAsRead(String otherUid) async {
    final me = _me;
    final cid = convId(me, otherUid);
    await _db.collection('conversations').doc(cid).update({
      'unread.$me': 0,
    });

    // Đánh dấu các message chưa đọc
    final unread = await _db
        .collection('conversations')
        .doc(cid)
        .collection('messages')
        .where('senderUid', isEqualTo: otherUid)
        .where('readBy', whereNotIn: [[me]])
        .limit(50)
        .get();

    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([me]),
      });
    }
    await batch.commit();
  }

  // ── Tổng unread của tất cả conversations ─────────────
  static Stream<int> totalUnreadStream() {
    final me = _me;
    return _db
        .collection('conversations')
        .where('participants', arrayContains: me)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final unreadMap =
            doc.data()['unread'] as Map<String, dynamic>? ?? {};
        total += ((unreadMap[me] ?? 0) as num).toInt();
      }
      return total;
    });
  }

  // ── Xoá tin nhắn (chỉ xoá phía mình) ────────────────
  static Future<void> deleteMessage(
      String otherUid, String messageId) async {
    final cid = convId(_me, otherUid);
    await _db
        .collection('conversations')
        .doc(cid)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedBy': FieldValue.arrayUnion([_me]),
    });
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class MessageModel {
  final String id;
  final String senderUid;
  final String text;
  final String type; // 'text' | 'image'
  final String? imageUrl;
  final DateTime? createdAt;
  final List<String> readBy;
  final List<String> deletedBy;

  const MessageModel({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.type,
    this.imageUrl,
    this.createdAt,
    required this.readBy,
    required this.deletedBy,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderUid: d['senderUid'] ?? '',
      text: d['text'] ?? '',
      type: d['type'] ?? 'text',
      imageUrl: d['imageUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(d['readBy'] ?? []),
      deletedBy: List<String>.from(d['deletedBy'] ?? []),
    );
  }

  bool isDeletedFor(String uid) => deletedBy.contains(uid);
  bool isReadBy(String uid) => readBy.contains(uid);
}

class ConversationModel {
  final String id;
  final String otherUid;
  final String otherName;
  final String otherPhoto;
  final String otherLevel;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderUid;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.otherUid,
    required this.otherName,
    required this.otherPhoto,
    required this.otherLevel,
    required this.lastMessage,
    this.lastMessageAt,
    required this.lastSenderUid,
    required this.unreadCount,
  });
}
