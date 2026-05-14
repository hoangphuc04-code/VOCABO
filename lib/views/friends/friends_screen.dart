import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/friend_service.dart';
import 'chat_screen.dart';

/// Màn hình bạn bè — tìm kiếm, danh sách, lời mời
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  String _lastQuery = '';

  static const _primary = Color(0xFF667eea);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    FriendService.ensureSearchable();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await FriendService.searchUsers(q);
    if (mounted && q == _lastQuery) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 56),
              title: const Text(
                'Bạn bè',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20, top: 40),
                    child: Text('👥', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: _primary,
                child: TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Bạn bè'),
                    Tab(text: 'Lời mời'),
                    Tab(text: 'Tìm kiếm'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _FriendsTab(),
            _RequestsTab(),
            _SearchTab(
              ctrl: _searchCtrl,
              results: _searchResults,
              searching: _searching,
              onSearch: _search,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1: Danh sách bạn bè ──────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendModel>>(
      stream: FriendService.friendsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)));
        }

        final friends = snap.data ?? [];

        if (friends.isEmpty) {
          return _EmptyState(
            icon: '👥',
            title: 'Chưa có bạn bè',
            subtitle: 'Tìm kiếm và kết bạn với người học tiếng Anh!',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _FriendCard(friend: friends[i]),
        );
      },
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendModel friend;
  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _Avatar(url: friend.photoURL, name: friend.displayName),
        title: Text(
          friend.displayName.isEmpty ? 'Người dùng' : friend.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            _LevelChip(level: friend.level),
            const SizedBox(width: 8),
            Text('🔥 ${friend.streak}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nút chat
            _IconBtn(
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF667eea),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    otherUid: friend.uid,
                    otherName: friend.displayName,
                    otherPhoto: friend.photoURL,
                    otherLevel: friend.level,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Nút huỷ kết bạn
            _IconBtn(
              icon: Icons.person_remove_outlined,
              color: Colors.red.shade400,
              onTap: () => _confirmUnfriend(context, friend),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnfriend(BuildContext context, FriendModel friend) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Huỷ kết bạn?'),
        content: Text(
            'Bạn có chắc muốn huỷ kết bạn với ${friend.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Không')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FriendService.unfriend(friend.uid);
            },
            child: const Text('Huỷ kết bạn',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Lời mời kết bạn ───────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: FriendService.incomingRequestsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)));
        }

        final requests = snap.data ?? [];

        if (requests.isEmpty) {
          return _EmptyState(
            icon: '📬',
            title: 'Không có lời mời',
            subtitle: 'Khi có người gửi lời mời kết bạn, bạn sẽ thấy ở đây',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _RequestCard(request: requests[i]),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  final FriendRequestModel request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF667eea).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _Avatar(
              url: widget.request.fromPhoto,
              name: widget.request.fromName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.fromName.isEmpty
                      ? 'Người dùng'
                      : widget.request.fromName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _LevelChip(level: widget.request.fromLevel),
                    const SizedBox(width: 6),
                    Text(
                      'muốn kết bạn với bạn',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_loading)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chấp nhận
                GestureDetector(
                  onTap: () => _accept(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF06D6A0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                // Từ chối
                GestureDetector(
                  onTap: () => _decline(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: Colors.red.shade400, size: 20),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    await FriendService.acceptRequest(widget.request.id);
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã kết bạn với ${widget.request.fromName}!'),
          backgroundColor: const Color(0xFF06D6A0),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    await FriendService.declineRequest(widget.request.id);
    if (mounted) setState(() => _loading = false);
  }
}

// ─── Tab 3: Tìm kiếm ─────────────────────────────────────────────────────────

class _SearchTab extends StatelessWidget {
  final TextEditingController ctrl;
  final List<Map<String, dynamic>> results;
  final bool searching;
  final void Function(String) onSearch;

  const _SearchTab({
    required this.ctrl,
    required this.results,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Mã của bạn ──────────────────────────────────
        _MyUserCodeCard(),

        // ── Search bar ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: ctrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Tên, #MÃ hoặc email...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF667eea)),
              suffixIcon: ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        ctrl.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // ── Gợi ý tìm theo mã ───────────────────────────
        if (ctrl.text.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  'Nhập #MÃ để tìm chính xác, ví dụ: #AB12CD',
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

        // ── Results ─────────────────────────────────────
        Expanded(
          child: searching
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF667eea)))
              : results.isEmpty
                  ? _EmptyState(
                      icon: '🔍',
                      title: ctrl.text.isEmpty
                          ? 'Tìm kiếm bạn bè'
                          : 'Không tìm thấy',
                      subtitle: ctrl.text.isEmpty
                          ? 'Nhập tên, #mã hoặc email để tìm kiếm'
                          : 'Thử tìm với từ khoá khác hoặc dùng #MÃ',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _SearchResultCard(user: results[i]),
                    ),
        ),
      ],
    );
  }
}

// ── Widget hiển thị mã của bản thân ──────────────────────────────────────────

class _MyUserCodeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: FriendService.myUserCodeStream(),
      builder: (context, snap) {
        final code = snap.data ?? '';
        if (code.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🪪', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mã của bạn',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              // Nút copy
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '#$code'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✅ Đã sao chép mã!'),
                      backgroundColor: const Color(0xFF06D6A0),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Sao chép',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final Map<String, dynamic> user;
  const _SearchResultCard({required this.user});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  FriendStatus _status = FriendStatus.none;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final s = await FriendService.getStatusWith(widget.user['uid']);
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['displayName'] ?? 'Người dùng';
    final photo = widget.user['photoURL'] ?? '';
    final level = widget.user['level'] ?? 'A1';
    final streak = (widget.user['streak'] ?? 0).toInt();
    final userCode = (widget.user['userCode'] ?? '') as String;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _Avatar(url: photo, name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                // Mã user
                if (userCode.isNotEmpty)
                  Text(
                    '#$userCode',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF667eea).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _LevelChip(level: level),
                    const SizedBox(width: 8),
                    Text('🔥 $streak',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildActionBtn(),
        ],
      ),
    );
  }

  Widget _buildActionBtn() {
    if (_loading) {
      return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    }

    switch (_status) {
      case FriendStatus.friends:
        return _StatusChip(
            label: 'Bạn bè', color: const Color(0xFF06D6A0));
      case FriendStatus.requestSent:
        return _StatusChip(label: 'Đã gửi', color: Colors.orange);
      case FriendStatus.requestReceived:
        return GestureDetector(
          onTap: _acceptIncoming,
          child: _StatusChip(
              label: 'Chấp nhận', color: const Color(0xFF667eea)),
        );
      case FriendStatus.none:
        return GestureDetector(
          onTap: _sendRequest,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Kết bạn',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
    }
  }

  Future<void> _sendRequest() async {
    setState(() => _loading = true);
    final result = await FriendService.sendRequest(widget.user['uid']);
    if (!mounted) return;
    setState(() => _loading = false);
    await _loadStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.message),
      backgroundColor:
          result.success ? const Color(0xFF06D6A0) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _acceptIncoming() async {
    setState(() => _loading = true);
    // Tìm request ID
    final requests = await FriendService.incomingRequestsStream().first;
    final req = requests.where((r) => r.fromUid == widget.user['uid']).firstOrNull;
    if (req != null) await FriendService.acceptRequest(req.id);
    if (mounted) {
      setState(() => _loading = false);
      await _loadStatus();
    }
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF667eea).withValues(alpha: 0.15),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Color(0xFF667eea),
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            )
          : null,
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: const TextStyle(
            color: Color(0xFF667eea),
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444))),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
