import 'package:flutter/material.dart';
import '../../data/services/context_import_service.dart';

/// 🎬 Context Import Screen — Học từ vựng qua Lyrics / Text / URL / SRT
class ContextImportScreen extends StatefulWidget {
  const ContextImportScreen({super.key});

  @override
  State<ContextImportScreen> createState() => _ContextImportScreenState();
}

class _ContextImportScreenState extends State<ContextImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  ContextSourceType _sourceType = ContextSourceType.lyrics;
  bool _loading = false;
  bool _fetchingUrl = false;
  ContextImportResult? _result;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() {
          _sourceType = [
            ContextSourceType.lyrics,
            ContextSourceType.text,
            ContextSourceType.url,
            ContextSourceType.srt,
          ][_tab.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      _showSnack('Vui lòng nhập URL hợp lệ (bắt đầu bằng https://)');
      return;
    }
    setState(() => _fetchingUrl = true);
    final result = await ContextImportService.fetchFromUrl(url);
    if (mounted) {
      setState(() => _fetchingUrl = false);
      if (result.success) {
        _titleCtrl.text = result.title;
        _contentCtrl.text = result.content;
        _showSnack('✅ Đã tải nội dung từ URL!', isSuccess: true);
      } else {
        _showSnack('❌ Không thể tải URL. Thử copy-paste nội dung thủ công.');
      }
    }
  }

  Future<void> _extract() async {
    String content = _contentCtrl.text.trim();
    // Nếu là SRT, parse trước
    if (_sourceType == ContextSourceType.srt) {
      content = ContextImportService.parseSrt(content);
    }
    if (content.isEmpty) {
      _showSnack('Vui lòng nhập nội dung!');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _showSnack('Vui lòng nhập tên nguồn!');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    final result = await ContextImportService.extractVocabulary(
      content: content,
      sourceTitle: _titleCtrl.text.trim(),
      sourceType: _sourceType,
    );
    if (mounted) {
      setState(() {
        _result = result;
        _loading = false;
      });
      if (result.words.isEmpty) {
        _showSnack('Không tìm thấy từ vựng phù hợp. Thử nội dung khác!');
      }
    }
  }

  Future<void> _saveSelected() async {
    if (_result == null) return;
    final selected = _result!.words.where((w) => w.isSelected).toList();
    if (selected.isEmpty) {
      _showSnack('Chọn ít nhất 1 từ để lưu!');
      return;
    }
    setState(() => _loading = true);
    final count = await ContextImportService.saveWordsToFirestore(
      words: selected,
      sourceTitle: _titleCtrl.text.trim(),
      sourceType: _sourceType,
    );
    if (mounted) {
      setState(() => _loading = false);
      _showSnack('✅ Đã lưu $count từ vào bộ flashcard!', isSuccess: true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isSuccess ? const Color(0xFF06D6A0) : const Color(0xFFFF4757),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        title: const Text('🎬 Học qua nội dung thực',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Text('🎵', style: TextStyle(fontSize: 16)), text: 'Lyrics'),
            Tab(icon: Text('📄', style: TextStyle(fontSize: 16)), text: 'Văn bản'),
            Tab(icon: Text('🌐', style: TextStyle(fontSize: 16)), text: 'URL'),
            Tab(icon: Text('🎬', style: TextStyle(fontSize: 16)), text: 'Subtitle'),
          ],
        ),
      ),
      body: _result != null ? _buildResult() : _buildInput(),
      floatingActionButton: _result != null
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _saveSelected,
              backgroundColor: const Color(0xFF667eea),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _loading
                    ? 'Đang lưu...'
                    : 'Lưu ${_result!.words.where((w) => w.isSelected).length} từ',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBanner(sourceType: _sourceType),
          const SizedBox(height: 20),

          // URL input (chỉ hiện khi tab URL)
          if (_sourceType == ContextSourceType.url) ...[
            const Text('URL bài báo / trang web',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      hintText: 'https://bbc.com/news/...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.link_rounded,
                          color: Color(0xFF667eea)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _fetchingUrl ? null : _fetchUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: _fetchingUrl
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Tải'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Title field
          const Text('Tên nguồn',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: _hintTitle,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Text(
                _sourceEmoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Content field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _sourceType == ContextSourceType.srt
                    ? 'Dán nội dung .SRT vào đây'
                    : _sourceType == ContextSourceType.url
                        ? 'Nội dung đã tải (có thể chỉnh sửa)'
                        : _sourceType == ContextSourceType.lyrics
                            ? 'Dán lyrics vào đây'
                            : 'Dán văn bản vào đây',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
              TextButton(
                onPressed: () => _contentCtrl.clear(),
                child: const Text('Xóa',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: TextField(
              controller: _contentCtrl,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: _hintContent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _extract,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white),
              label: Text(
                _loading ? 'AI đang phân tích...' : '✨ Trích xuất từ vựng',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ExamplesSection(sourceType: _sourceType),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String get _hintTitle => switch (_sourceType) {
        ContextSourceType.lyrics => 'VD: Shape of You - Ed Sheeran',
        ContextSourceType.url => 'Tên bài báo (tự động điền)',
        ContextSourceType.srt => 'VD: Breaking Bad S01E01',
        _ => 'VD: Bài báo về AI',
      };

  String get _sourceEmoji => switch (_sourceType) {
        ContextSourceType.lyrics => '🎵',
        ContextSourceType.url => '🌐',
        ContextSourceType.srt => '🎬',
        _ => '📄',
      };

  String get _hintContent => switch (_sourceType) {
        ContextSourceType.lyrics =>
          'Paste lyrics bài hát tiếng Anh vào đây...',
        ContextSourceType.url =>
          'Nội dung sẽ tự động điền sau khi nhấn Tải...',
        ContextSourceType.srt =>
          'Paste nội dung file .SRT subtitle vào đây...\n\n1\n00:00:01,000 --> 00:00:04,000\nHello, how are you?\n\n2\n00:00:05,000 --> 00:00:08,000\nI am fine, thank you.',
        _ => 'Paste đoạn văn bản tiếng Anh vào đây...',
      };

  Widget _buildResult() {
    final words = _result!.words;
    final selectedCount = words.where((w) => w.isSelected).length;

    return Column(
      children: [
        Container(
          color: const Color(0xFF667eea),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Tìm thấy ${words.length} từ vựng',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      'Từ: ${_titleCtrl.text}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final w in words) {
                    w.isSelected = !w.isSelected;
                  }
                }),
                child: Text(
                  selectedCount == words.length
                      ? 'Bỏ chọn tất cả'
                      : 'Chọn tất cả',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _result = null),
                child: const Text('← Nhập lại',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: words.length,
            itemBuilder: (_, i) => _WordCard(
              word: words[i],
              onToggle: () => setState(() {
                words[i].isSelected = !words[i].isSelected;
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Info Banner ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final ContextSourceType sourceType;
  const _InfoBanner({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final (emoji, title, desc) = switch (sourceType) {
      ContextSourceType.lyrics => ('🎵', 'Học qua bài hát', 'Paste lyrics → AI trích xuất từ hay → Tạo flashcard'),
      ContextSourceType.url => ('🌐', 'Học qua bài báo', 'Nhập URL → Tự động tải nội dung → Trích xuất từ vựng'),
      ContextSourceType.srt => ('🎬', 'Học qua phim/series', 'Paste file .SRT subtitle → AI trích xuất từ khó → Flashcard'),
      _ => ('📄', 'Học qua văn bản', 'Paste bài báo/truyện → AI trích xuất từ khó → Tạo flashcard'),
    };
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Word Card ────────────────────────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  final ContextWord word;
  final VoidCallback onToggle;
  const _WordCard({required this.word, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: word.isSelected ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: word.isSelected
              ? const Color(0xFF667eea).withOpacity(0.3)
              : Colors.transparent,
        ),
        boxShadow: word.isSelected
            ? [
                BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: word.isSelected
                  ? const Color(0xFF667eea)
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              word.isSelected ? Icons.check_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(word.word,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: word.isSelected
                        ? const Color(0xFF222222)
                        : Colors.grey)),
            const SizedBox(width: 8),
            if (word.phonetic.isNotEmpty)
              Text(word.phonetic,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(word.meaning,
                style: TextStyle(
                    fontSize: 13,
                    color: word.isSelected
                        ? const Color(0xFF667eea)
                        : Colors.grey,
                    fontWeight: FontWeight.w500)),
            if (word.contextSentence.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '"${word.contextSentence}"',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}

// ─── Examples Section ─────────────────────────────────────────────────────────

class _ExamplesSection extends StatelessWidget {
  final ContextSourceType sourceType;
  const _ExamplesSection({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final examples = switch (sourceType) {
      ContextSourceType.lyrics => [
          '🎵 Shape of You - Ed Sheeran',
          '🎵 Blinding Lights - The Weeknd',
          '🎵 Someone Like You - Adele',
        ],
      ContextSourceType.url => [
          '📰 https://bbc.com/news/...',
          '📰 https://cnn.com/...',
          '📰 https://techcrunch.com/...',
        ],
      ContextSourceType.srt => [
          '🎬 Breaking Bad subtitle',
          '🎬 Friends S01E01.srt',
          '🎬 The Office subtitle',
        ],
      _ => [
          '📰 Bài báo BBC/CNN',
          '📖 Đoạn truyện tiếng Anh',
          '📧 Email công việc',
        ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💡 Gợi ý nguồn nội dung:',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: examples
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.2)),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF667eea))),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
