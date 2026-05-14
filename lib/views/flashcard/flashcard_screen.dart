import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vocabodemo/core/utils/responsive.dart';

import 'learn_screen.dart';

////////////////////////////////////////////////////////////
/// PRESET TOPICS — chủ đề có sẵn với danh sách từ vựng
////////////////////////////////////////////////////////////

class PresetTopic {
  final String name;
  final String nameVi;
  final String emoji;
  final Color color;
  final List<String> words;

  const PresetTopic({
    required this.name,
    required this.nameVi,
    required this.emoji,
    required this.color,
    required this.words,
  });
}

const List<PresetTopic> kPresetTopics = [
  PresetTopic(
    name: "Animals",
    nameVi: "Động vật",
    emoji: "🐾",
    color: Color(0xFFFF6B6B),
    words: [
      "elephant","lion","tiger","dolphin","eagle","rabbit","wolf",
      "giraffe","penguin","crocodile","butterfly","octopus","kangaroo",
      "cheetah","gorilla","flamingo","panda","koala","jaguar","hawk",
    ],
  ),
  PresetTopic(
    name: "Food",
    nameVi: "Đồ ăn",
    emoji: "🍎",
    color: Color(0xFFFF9F1C),
    words: [
      "apple","banana","mango","strawberry","avocado","broccoli",
      "salmon","noodle","rice","cheese","chocolate","mushroom",
      "pineapple","coconut","almond","blueberry","cucumber","tomato",
      "watermelon","lemon",
    ],
  ),
  PresetTopic(
    name: "Travel",
    nameVi: "Du lịch",
    emoji: "✈️",
    color: Color(0xFF3A86FF),
    words: [
      "passport","luggage","airport","hotel","tourism","adventure",
      "destination","journey","ticket","reservation","landmark",
      "souvenir","itinerary","explore","culture","museum","beach",
      "mountain","cruise","backpack",
    ],
  ),
  PresetTopic(
    name: "Technology",
    nameVi: "Công nghệ",
    emoji: "💻",
    color: Color(0xFF8338EC),
    words: [
      "algorithm","database","network","software","hardware","cybersecurity",
      "artificial","interface","bandwidth","processor","wireless","browser",
      "download","encryption","firewall","server","protocol","digital",
      "innovation","automation",
    ],
  ),
  PresetTopic(
    name: "Business",
    nameVi: "Kinh doanh",
    emoji: "💼",
    color: Color(0xFF06D6A0),
    words: [
      "investment","revenue","profit","strategy","marketing","entrepreneur",
      "contract","negotiation","dividend","budget","shareholder","merger",
      "bankruptcy","franchise","commodity","inflation","interest","assets",
      "liability","capital",
    ],
  ),
  PresetTopic(
    name: "Health",
    nameVi: "Sức khoẻ",
    emoji: "❤️",
    color: Color(0xFFFF006E),
    words: [
      "medicine","symptom","diagnosis","therapy","nutrition","exercise",
      "vitamin","antibody","immune","vaccine","surgeon","pharmacy",
      "mental","anxiety","depression","recovery","prevention","hygiene",
      "cardiovascular","metabolism",
    ],
  ),
  PresetTopic(
    name: "Nature",
    nameVi: "Thiên nhiên",
    emoji: "🌿",
    color: Color(0xFF2EC4B6),
    words: [
      "forest","ocean","desert","volcano","glacier","ecosystem",
      "biodiversity","atmosphere","hurricane","earthquake","waterfall",
      "coral","drought","erosion","habitat","fossil","mineral",
      "rainfall","climate","lightning",
    ],
  ),
  PresetTopic(
    name: "Education",
    nameVi: "Giáo dục",
    emoji: "🎓",
    color: Color(0xFFFFBE0B),
    words: [
      "knowledge","scholarship","curriculum","academic","research",
      "examination","diploma","graduate","lecture","laboratory",
      "thesis","semester","tuition","discipline","textbook","assignment",
      "concept","theory","skill","certificate",
    ],
  ),
];

////////////////////////////////////////////////////////////
/// MODEL
////////////////////////////////////////////////////////////

class VocabTopic {
  final String id;
  final String name;
  final String nameVi;
  final String emoji;
  final Color color;
  final int wordCount;
  final bool isPreset;

  const VocabTopic({
    required this.id,
    required this.name,
    required this.nameVi,
    required this.emoji,
    required this.color,
    required this.wordCount,
    this.isPreset = false,
  });

  factory VocabTopic.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VocabTopic(
      id:        doc.id,
      name:      d["name"]      as String? ?? "",
      nameVi:    d["nameVi"]    as String? ?? "",
      emoji:     d["emoji"]     as String? ?? "📚",
      color:     Color(int.parse(
          (d["color"] as String? ?? "FF667eea").replaceFirst("#", "0xFF"))),
      wordCount: (d["wordCount"] as num? ?? 0).toInt(),
      isPreset:  d["isPreset"]  as bool? ?? false,
    );
  }

  // Tạo từ PresetTopic (chưa có trong Firestore)
  static VocabTopic fromPreset(PresetTopic p) => VocabTopic(
    id:        "",
    name:      p.name,
    nameVi:    p.nameVi,
    emoji:     p.emoji,
    color:     p.color,
    wordCount: p.words.length,
    isPreset:  true,
  );
}

////////////////////////////////////////////////////////////
/// FLASHCARD SCREEN
////////////////////////////////////////////////////////////

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: r.w(140),
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: r.hPad, bottom: 60),
              title: Text(
                "Học từ vựng",
                style: TextStyle(
                  fontSize: r.sp(20),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: r.hPad, top: 40),
                    child: Text("📖", style: TextStyle(fontSize: r.sp(48))),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 10),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFF667eea),
                    unselectedLabelColor: Colors.white,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: r.sp(14),
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: r.sp(14),
                    ),
                    tabs: const [
                      Tab(text: "Chủ đề có sẵn"),
                      Tab(text: "Của tôi"),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton(
                  onPressed: () => _showAddTopicDialog(context),
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          )
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _PresetTopicsTab(),
            _MyTopicsTab(onAddTopic: () => _showAddTopicDialog(context)),
          ],
        ),
      ),
    );
  }

  void _showAddTopicDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddTopicSheet(),
    );
  }
}

////////////////////////////////////////////////////////////
/// TAB 1 — PRESET TOPICS
////////////////////////////////////////////////////////////

class _PresetTopicsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GridView.builder(
      padding: EdgeInsets.all(r.hPad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: r.gridCols(phone: 2, tablet: 3, largeTablet: 4),
        mainAxisSpacing: r.w(14),
        crossAxisSpacing: r.w(14),
        childAspectRatio: r.isAnyTablet ? 1.1 : 1.05,
      ),
      itemCount: kPresetTopics.length,
      itemBuilder: (context, i) {
        final preset = kPresetTopics[i];
        return _PresetTopicCard(
          preset: preset,
          onTap: () => _openPreset(context, preset),
        );
      },
    );
  }

  // Khi tap: tạo topic trong Firestore nếu chưa có, rồi seed từ vựng
  Future<void> _openPreset(
      BuildContext context, PresetTopic preset) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Hiện loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(),
    );

    try {
      // Kiểm tra topic đã tồn tại chưa
      final existing = await FirebaseFirestore.instance
          .collection("topics")
          .where("uid", isEqualTo: user.uid)
          .where("name", isEqualTo: preset.name)
          .where("isPreset", isEqualTo: true)
          .get();

      String topicId;
      int actualWordCount = 0;

      if (existing.docs.isNotEmpty) {
        topicId = existing.docs.first.id;

        // Kiểm tra wordCount thực tế — nếu = 0 thì re-seed
        final wordsSnap = await FirebaseFirestore.instance
            .collection("topics")
            .doc(topicId)
            .collection("words")
            .get();
        actualWordCount = wordsSnap.docs.length;

        if (actualWordCount == 0) {
          // Re-seed vì lần trước bị lỗi
          await _seedWords(topicId, preset.words);
          actualWordCount = await FirebaseFirestore.instance
              .collection("topics")
              .doc(topicId)
              .collection("words")
              .get()
              .then((s) => s.docs.length);
          await FirebaseFirestore.instance
              .collection("topics")
              .doc(topicId)
              .update({"wordCount": actualWordCount});
        } else if (existing.docs.first.data()["wordCount"] != actualWordCount) {
          // Sync lại wordCount nếu lệch
          await FirebaseFirestore.instance
              .collection("topics")
              .doc(topicId)
              .update({"wordCount": actualWordCount});
        }
      } else {
        // Chưa có → tạo mới + seed từ vựng
        final colorHex =
            "#${preset.color.value.toRadixString(16).substring(2)}";

        final docRef =
        await FirebaseFirestore.instance.collection("topics").add({
          "uid":       user.uid,
          "name":      preset.name,
          "nameVi":    preset.nameVi,
          "emoji":     preset.emoji,
          "color":     colorHex,
          "wordCount": 0,
          "isPreset":  true,
          "createdAt": FieldValue.serverTimestamp(),
        });

        topicId = docRef.id;

        // Seed từ vựng từ API
        await _seedWords(topicId, preset.words);

        // Cập nhật wordCount
        final actualCount = await FirebaseFirestore.instance
            .collection("topics")
            .doc(topicId)
            .collection("words")
            .get()
            .then((s) => s.docs.length);

        await FirebaseFirestore.instance
            .collection("topics")
            .doc(topicId)
            .update({"wordCount": actualCount});
      }

      if (context.mounted) Navigator.pop(context); // đóng loading

      final topic = VocabTopic(
        id:        topicId,
        name:      preset.name,
        nameVi:    preset.nameVi,
        emoji:     preset.emoji,
        color:     preset.color,
        wordCount: actualWordCount > 0 ? actualWordCount : preset.words.length,
        isPreset:  true,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LearnFlashcardScreen(topic: topic)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
      }
    }
  }

  // Seed từ vựng: gọi song song tất cả, timeout ngắn để không block lâu
  Future<void> _seedWords(String topicId, List<String> words) async {
    final ref = FirebaseFirestore.instance
        .collection("topics")
        .doc(topicId)
        .collection("words");

    // Kiểm tra từ nào đã có để không seed lại
    final existing = await ref.get();
    final existingWords = existing.docs
        .map((d) => d.data()["word"] as String? ?? "")
        .toSet();

    final toSeed = words.where((w) => !existingWords.contains(w)).toList();
    if (toSeed.isEmpty) return;

    // Gọi song song theo batch 8 từ
    for (int i = 0; i < toSeed.length; i += 8) {
      final batch = toSeed.sublist(
          i, i + 8 > toSeed.length ? toSeed.length : i + 8);
      await Future.wait(batch.map((w) => _fetchAndSaveWord(ref, w)));
    }
  }

  Future<void> _fetchAndSaveWord(
      CollectionReference ref, String word) async {
    try {
      // 1. Dictionary API — lấy phonetic + example
      final dictRes = await http
          .get(Uri.parse(
          "https://api.dictionaryapi.dev/api/v2/entries/en/$word"))
          .timeout(const Duration(seconds: 8));

      String phonetic = "";
      String example  = "";
      String defEn    = "";

      if (dictRes.statusCode == 200) {
        final data = jsonDecode(dictRes.body) as List;
        if (data.isNotEmpty) {
          final entry = data[0] as Map<String, dynamic>;

          // Phonetic
          phonetic = entry["phonetic"] as String? ?? "";
          if (phonetic.isEmpty) {
            final phonetics = entry["phonetics"] as List? ?? [];
            for (final p in phonetics) {
              final t = (p as Map)["text"] as String? ?? "";
              if (t.isNotEmpty) { phonetic = t; break; }
            }
          }

          // Definition + Example
          final meanings = entry["meanings"] as List? ?? [];
          for (final m in meanings) {
            final defs = (m as Map)["definitions"] as List? ?? [];
            for (final d in defs) {
              defEn   = (d as Map)["definition"] as String? ?? "";
              example = d["example"]   as String? ?? "";
              if (defEn.isNotEmpty) break;
            }
            if (defEn.isNotEmpty) break;
          }
        }
      }

      // 2. MyMemory API — dịch nghĩa sang tiếng Việt (miễn phí, no key)
      String meaningVi  = "";
      String exampleVi  = "";

      if (defEn.isNotEmpty) {
        meaningVi = await _translate(word);
        if (example.isNotEmpty) {
          exampleVi = await _translate(example);
        } else {
          // Tự tạo câu ví dụ đơn giản nếu Dictionary API không có
          example   = _buildFallbackExample(word, defEn);
          exampleVi = await _translate(example);
        }
      } else {
        // Fallback: chỉ dịch từ đơn
        meaningVi = await _translate(word);
        // Tạo câu ví dụ cơ bản
        example   = _buildFallbackExample(word, "");
        exampleVi = await _translate(example);
      }

      // 3. Lưu vào Firestore
      await ref.add({
        "word":      word,
        "meaning":   meaningVi.isNotEmpty ? meaningVi : word,
        "phonetic":  phonetic,
        "example":   example,
        "exampleVi": exampleVi,
        "imageUrl":  "",
        "createdAt": FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Nếu lỗi → lưu từ với dữ liệu tối thiểu
      try {
        await ref.add({
          "word":      word,
          "meaning":   word,
          "phonetic":  "",
          "example":   "",
          "exampleVi": "",
          "imageUrl":  "",
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  // MyMemory translate — free, 5000 ký tự/ngày, no API key
  Future<String> _translate(String text) async {
    try {
      final uri = Uri.parse(
        "https://api.mymemory.translated.net/get"
            "?q=${Uri.encodeComponent(text)}&langpair=en|vi",
      );
      final res =
      await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return json["responseData"]?["translatedText"] as String? ?? "";
      }
    } catch (_) {}
    return "";
  }

  // Tạo câu ví dụ đơn giản khi Dictionary API không có sẵn
  String _buildFallbackExample(String word, String definition) {
    // Các mẫu câu ví dụ đơn giản theo dạng từ
    final templates = [
      "The $word is very important in our daily life.",
      "She learned about $word in her English class.",
      "He used the word $word correctly in his essay.",
      "Understanding $word helps you communicate better.",
      "The teacher explained what $word means to the students.",
    ];

    // Chọn template dựa trên hash của từ để luôn nhất quán
    final idx = word.codeUnits.fold(0, (a, b) => a + b) % templates.length;
    return templates[idx];
  }
}

////////////////////////////////////////////////////////////
/// PRESET TOPIC CARD
////////////////////////////////////////////////////////////

class _PresetTopicCard extends StatelessWidget {
  final PresetTopic preset;
  final VoidCallback onTap;
  const _PresetTopicCard({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              preset.color.withOpacity(0.9),
              preset.color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(r.r(20)),
          boxShadow: [
            BoxShadow(
              color: preset.color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Badge số từ
            Positioned(
              top: r.w(12), right: r.w(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(8), vertical: r.w(3)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${preset.words.length} từ",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(11),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Nội dung
            Padding(
              padding: EdgeInsets.all(r.w(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(preset.emoji,
                      style: TextStyle(fontSize: r.sp(34))),
                  SizedBox(height: r.w(8)),
                  Text(
                    preset.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.w(2)),
                  Text(
                    preset.nameVi,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: r.sp(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// TAB 2 — MY TOPICS (người dùng tự tạo)
////////////////////////////////////////////////////////////

class _MyTopicsTab extends StatelessWidget {
  final VoidCallback onAddTopic;
  const _MyTopicsTab({required this.onAddTopic});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Vui lòng đăng nhập"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("topics")
          .where("uid", isEqualTo: user.uid)
          .where("isPreset", isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF667eea)));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyMyTopics(onAdd: onAddTopic);
        }

        final topics =
        docs.map((d) => VocabTopic.fromDoc(d)).toList();

        return GridView.builder(
          padding: EdgeInsets.all(r.hPad),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: r.gridCols(phone: 2, tablet: 3, largeTablet: 4),
            mainAxisSpacing: r.w(14),
            crossAxisSpacing: r.w(14),
            childAspectRatio: r.isAnyTablet ? 1.1 : 1.05,
          ),
          itemCount: topics.length,
          itemBuilder: (context, i) => _MyTopicCard(
            topic: topics[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      LearnFlashcardScreen(topic: topics[i])),
            ),
            onDelete: () => _deleteTopic(context, topics[i].id),
          ),
        );
      },
    );
  }

  Future<void> _deleteTopic(
      BuildContext context, String topicId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xoá chủ đề?"),
        content: const Text(
            "Tất cả từ vựng trong chủ đề này sẽ bị xoá vĩnh viễn."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Huỷ")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Xoá",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final words = await FirebaseFirestore.instance
        .collection("topics")
        .doc(topicId)
        .collection("words")
        .get();
    for (var w in words.docs) {
      await w.reference.delete();
    }
    await FirebaseFirestore.instance
        .collection("topics")
        .doc(topicId)
        .delete();
  }
}

////////////////////////////////////////////////////////////
/// MY TOPIC CARD — đọc wordCount realtime từ subcollection
////////////////////////////////////////////////////////////

class _MyTopicCard extends StatelessWidget {
  final VocabTopic topic;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MyTopicCard({
    required this.topic,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              topic.color.withOpacity(0.85),
              topic.color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(r.r(20)),
          boxShadow: [
            BoxShadow(
              color: topic.color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: r.w(12), right: r.w(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(8), vertical: r.w(3)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("topics")
                      .doc(topic.id)
                      .collection("words")
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? topic.wordCount;
                    if (snap.hasData && count != topic.wordCount && topic.id.isNotEmpty) {
                      FirebaseFirestore.instance
                          .collection("topics")
                          .doc(topic.id)
                          .update({"wordCount": count})
                          .catchError((_) {});
                    }
                    return Text(
                      "$count từ",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: r.sp(11),
                          fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r.w(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(topic.emoji,
                      style: TextStyle(fontSize: r.sp(34))),
                  SizedBox(height: r.w(8)),
                  Text(
                    topic.name,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: r.sp(16),
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.w(2)),
                  Text(
                    topic.nameVi,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: r.sp(12)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// EMPTY STATE
////////////////////////////////////////////////////////////

class _EmptyMyTopics extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyMyTopics({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.hPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("📚", style: TextStyle(fontSize: r.sp(60))),
            SizedBox(height: r.w(16)),
            Text(
              "Chưa có chủ đề nào",
              style: TextStyle(
                  fontSize: r.sp(17),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444)),
            ),
            SizedBox(height: r.w(8)),
            Text(
              "Nhấn + để tạo chủ đề từ vựng của riêng bạn",
              style: TextStyle(color: Colors.grey, fontSize: r.sp(13)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.w(24)),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text("Tạo chủ đề"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(28), vertical: r.w(14)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.r(16))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// LOADING DIALOG
////////////////////////////////////////////////////////////

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF667eea)),
            SizedBox(height: 20),
            Text(
              "Đang tải từ vựng...",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 6),
            Text(
              "Lần đầu mất khoảng 10-20 giây",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// ADD TOPIC SHEET (tạo chủ đề thủ công)
////////////////////////////////////////////////////////////

class _AddTopicSheet extends StatefulWidget {
  const _AddTopicSheet();

  @override
  State<_AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends State<_AddTopicSheet> {
  final _nameEn = TextEditingController();
  final _nameVi = TextEditingController();
  String _emoji = "📚";
  Color _color  = const Color(0xFF667eea);
  bool _loading = false;

  static const _emojis = [
    "📚","🐾","🍎","🏠","✈️","💼","🎵","⚽","🌿","🔬",
    "🎨","🍜","🌍","💻","❤️","🧠","🏔️","🌊","🎓","🛒",
  ];
  static const _colors = [
    Color(0xFF667eea), Color(0xFFFF6B6B), Color(0xFF4ECDC4),
    Color(0xFFFFBE0B), Color(0xFF06D6A0), Color(0xFFFF9F1C),
    Color(0xFF8338EC), Color(0xFF3A86FF), Color(0xFFFF006E),
    Color(0xFF2EC4B6),
  ];

  Future<void> _save() async {
    if (_nameEn.text.trim().isEmpty) return;
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection("topics").add({
      "uid":       user.uid,
      "name":      _nameEn.text.trim(),
      "nameVi":    _nameVi.text.trim(),
      "emoji":     _emoji,
      "color":     "#${_color.value.toRadixString(16).substring(2)}",
      "wordCount": 0,
      "isPreset":  false,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Tạo chủ đề mới",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _buildField(_nameEn, "Tên tiếng Anh *", "My Topic"),
            const SizedBox(height: 10),
            _buildField(_nameVi, "Tên tiếng Việt", "Chủ đề của tôi"),
            const SizedBox(height: 16),
            const Text("Biểu tượng",
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _emojis.map((e) {
                final sel = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: sel
                          ? _color.withOpacity(0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: sel
                          ? Border.all(color: _color, width: 2)
                          : null,
                    ),
                    child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text("Màu sắc",
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _colors.map((c) {
                final sel = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: sel
                          ? [BoxShadow(
                          color: c.withOpacity(0.5),
                          blurRadius: 6)]
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check,
                        color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text("Tạo chủ đề",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF667eea), width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameVi.dispose();
    super.dispose();
  }
}