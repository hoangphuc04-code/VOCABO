import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/cloudinary_service.dart';

/// Màn hình chat 1-1
class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;
  final String otherPhoto;
  final String otherLevel;

  const ChatScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
    required this.otherPhoto,
    required this.otherLevel,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _me = FirebaseAuth.instance.currentUser!.uid;
  bool _sending = false;
  bool _uploadingImage = false;

  static const _primary = Color(0xFF667eea);

  @override
  void initState() {
    super.initState();
    // Đánh dấu đã đọc khi mở chat
    ChatService.markAsRead(widget.otherUid);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        if (animated) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    await ChatService.sendMessage(toUid: widget.otherUid, text: text);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 1024);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final file = File(picked.path);
      // Upload lên Cloudinary (dùng timestamp làm uid để tránh overwrite)
      final uid = 'chat_${DateTime.now().millisecondsSinceEpoch}';
      final url = await CloudinaryService.uploadAvatar(file, uid);
      if (url.isNotEmpty) {
        await ChatService.sendMessage(
          toUid: widget.otherUid,
          text: '📷 Hình ảnh',
          imageUrl: url,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi ảnh')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F8),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _ChatAvatar(url: widget.otherPhoto, name: widget.otherName, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName.isEmpty ? 'Người dùng' : widget.otherName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.otherLevel,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded,
              color: Colors.white, size: 22),
          onPressed: () => _showOptions(context),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<MessageModel>>(
      stream: ChatService.messagesStream(widget.otherUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }

        final messages = (snap.data ?? [])
            .where((m) => !m.isDeletedFor(_me))
            .toList();

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👋', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Bắt đầu cuộc trò chuyện với\n${widget.otherName}!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        // Đánh dấu đã đọc
        ChatService.markAsRead(widget.otherUid);

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(animated: false));

        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            final isMe = msg.senderUid == _me;
            final showDate = i == 0 ||
                _isDifferentDay(
                    messages[i - 1].createdAt, msg.createdAt);

            return Column(
              children: [
                if (showDate) _DateDivider(date: msg.createdAt),
                _MessageBubble(
                  message: msg,
                  isMe: isMe,
                  showAvatar: !isMe &&
                      (i == messages.length - 1 ||
                          messages[i + 1].senderUid != msg.senderUid),
                  otherPhoto: widget.otherPhoto,
                  otherName: widget.otherName,
                  onLongPress: () => _showMessageOptions(context, msg, isMe),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image button
          GestureDetector(
            onTap: _uploadingImage ? null : _pickAndSendImage,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _uploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary))
                  : const Icon(Icons.image_outlined,
                      color: _primary, size: 20),
            ),
          ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Nhắn tin...',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctrl,
            builder: (_, val, __) {
              final active = val.text.trim().isNotEmpty && !_sending;
              return GestureDetector(
                onTap: active ? _send : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: active ? _primary : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          Icons.send_rounded,
                          color: active
                              ? Colors.white
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Xem hồ sơ'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: Colors.red.shade400),
              title: Text('Huỷ kết bạn',
                  style: TextStyle(color: Colors.red.shade400)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(
      BuildContext context, MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            // Preview tin nhắn
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg.text.length > 60
                    ? '${msg.text.substring(0, 60)}...'
                    : msg.text,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Sao chép'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Đã sao chép'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400),
                title: Text('Xoá tin nhắn',
                    style: TextStyle(color: Colors.red.shade400)),
                onTap: () async {
                  Navigator.pop(context);
                  await ChatService.deleteMessage(
                      widget.otherUid, msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final String otherPhoto;
  final String otherName;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.otherPhoto,
    required this.otherName,
    required this.onLongPress,
  });

  static const _primary = Color(0xFF667eea);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar người kia
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: showAvatar
                  ? _ChatAvatar(
                      url: otherPhoto, name: otherName, size: 14)
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.68,
                ),
                margin: EdgeInsets.only(
                  left: isMe ? 60 : 0,
                  right: isMe ? 0 : 60,
                ),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Image message
                    if (message.type == 'image' &&
                        message.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          message.imageUrl!,
                          width: 200,
                          height: 160,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      width: 200,
                                      height: 160,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                    ),
                        ),
                      ),

                    // Text message
                    if (message.text.isNotEmpty &&
                        message.text != '📷 Hình ảnh')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? _primary
                              : isDark
                                  ? const Color(0xFF2A2A3E)
                                  : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                                Radius.circular(isMe ? 18 : 4),
                            bottomRight:
                                Radius.circular(isMe ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isMe
                                  ? _primary.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),

                    // Time + read status
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.createdAt != null
                                ? DateFormat('HH:mm')
                                    .format(message.createdAt!)
                                : '',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            Icon(
                              message.readBy.length > 1
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 13,
                              color: message.readBy.length > 1
                                  ? _primary
                                  : Colors.grey.shade400,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Date Divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime? date;
  const _DateDivider({this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();

    final now = DateTime.now();
    String label;
    if (date!.day == now.day &&
        date!.month == now.month &&
        date!.year == now.year) {
      label = 'Hôm nay';
    } else if (date!.day == now.subtract(const Duration(days: 1)).day) {
      label = 'Hôm qua';
    } else {
      label = DateFormat('dd/MM/yyyy').format(date!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }
}

// ─── Chat Avatar ──────────────────────────────────────────────────────────────

class _ChatAvatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  const _ChatAvatar(
      {required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor:
          const Color(0xFF667eea).withValues(alpha: 0.15),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: const Color(0xFF667eea),
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.8),
            )
          : null,
    );
  }
}
