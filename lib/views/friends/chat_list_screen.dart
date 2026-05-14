import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/friend_service.dart';
import 'chat_screen.dart';
import 'friends_screen.dart';

/// Màn hình danh sách cuộc trò chuyện
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  static const _primary = Color(0xFF667eea);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          // Nút đến trang bạn bè
          IconButton(
            icon: const Icon(Icons.people_outline_rounded,
                color: Colors.white, size: 24),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
            tooltip: 'Bạn bè',
          ),
          // Badge lời mời
          StreamBuilder<int>(
            stream: FriendService.pendingRequestCountStream(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined,
                        color: Colors.white, size: 24),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FriendsScreen()),
                    ),
                    tooltip: 'Lời mời kết bạn',
                  ),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: ChatService.conversationsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _primary));
          }

          final conversations = snap.data ?? [];

          if (conversations.isEmpty) {
            return _EmptyConversations(
              onFindFriends: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendsScreen()),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              color: Colors.grey.shade100,
            ),
            itemBuilder: (context, i) =>
                _ConversationTile(conv: conversations[i]),
          );
        },
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  const _ConversationTile({required this.conv});

  static const _primary = Color(0xFF667eea);
  static final _me = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final isUnread = conv.unreadCount > 0;
    final isMyMessage = conv.lastSenderUid == _me;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUid: conv.otherUid,
            otherName: conv.otherName,
            otherPhoto: conv.otherPhoto,
            otherLevel: conv.otherLevel,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      _primary.withValues(alpha: 0.15),
                  backgroundImage: conv.otherPhoto.isNotEmpty
                      ? NetworkImage(conv.otherPhoto)
                      : null,
                  child: conv.otherPhoto.isEmpty
                      ? Text(
                          conv.otherName.isNotEmpty
                              ? conv.otherName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        )
                      : null,
                ),
                // Level badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      conv.otherLevel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.otherName.isEmpty
                              ? 'Người dùng'
                              : conv.otherName,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(conv.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnread
                              ? _primary
                              : Colors.grey.shade500,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isMyMessage)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          conv.lastMessage.isEmpty
                              ? 'Bắt đầu trò chuyện...'
                              : conv.lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUnread
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.grey.shade500,
                            fontWeight: isUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              conv.unreadCount > 9
                                  ? '9+'
                                  : '${conv.unreadCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    if (dt.year == now.year) return DateFormat('dd/MM').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyConversations extends StatelessWidget {
  final VoidCallback onFindFriends;
  const _EmptyConversations({required this.onFindFriends});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'Chưa có tin nhắn nào',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 10),
            Text(
              'Kết bạn và bắt đầu trò chuyện\nvới những người học tiếng Anh!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onFindFriends,
              icon: const Icon(Icons.people_rounded, size: 18),
              label: const Text('Tìm bạn bè'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
