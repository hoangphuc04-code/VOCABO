import 'package:flutter/material.dart';
import '../../data/services/friend_service.dart';
import '../../data/services/house_service.dart';
import 'house_screen.dart';

/// 👥 Màn hình thăm nhà bạn bè
class VisitFriendsScreen extends StatelessWidget {
  const VisitFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '👥 Thăm nhà bạn bè',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<FriendModel>>(
        stream: FriendService.friendsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35)));
          }

          final friends = snap.data ?? [];

          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏠', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có bạn bè',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444444)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kết bạn để thăm nhà của họ!',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _FriendHouseCard(friend: friends[i]),
          );
        },
      ),
    );
  }
}

class _FriendHouseCard extends StatelessWidget {
  final FriendModel friend;
  const _FriendHouseCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HouseData>(
      future: HouseService.getHouse(friend.uid),
      builder: (context, snap) {
        final house = snap.data;
        final pet = house?.pet;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundImage: friend.photoURL.isNotEmpty
                    ? NetworkImage(friend.photoURL)
                    : null,
                backgroundColor:
                    const Color(0xFF667eea).withValues(alpha: 0.15),
                child: friend.photoURL.isEmpty
                    ? Text(
                        friend.displayName.isNotEmpty
                            ? friend.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName.isEmpty
                          ? 'Người dùng'
                          : friend.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (pet != null) ...[
                          Text(pet.emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            pet.name,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            friend.level,
                            style: const TextStyle(
                                color: Color(0xFF667eea),
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Visit button
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HouseScreen(ownerUid: friend.uid),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Thăm',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
