// game_data.dart — Dữ liệu từ vựng và cấu hình cho các game

class WordPair {
  final String word;
  final String meaning;
  const WordPair(this.word, this.meaning);
}

class GameData {
  static const totalLevels = 10;

  /// Từ vựng theo level (mỗi level thêm từ khó hơn)
  static List<WordPair> getWords(int level) {
    final all = _allWords;
    // Mỗi level lấy thêm 20 từ, overlap với level trước
    final start = ((level - 1) * 15).clamp(0, all.length - 20);
    final end = (start + 20 + level * 5).clamp(0, all.length);
    return all.sublist(start, end);
  }

  static int timeLimitForLevel(int level) => (90 - level * 5).clamp(30, 90);

  static const _allWords = <WordPair>[
    // Level 1 — cơ bản
    WordPair('apple', 'táo'),
    WordPair('book', 'sách'),
    WordPair('cat', 'mèo'),
    WordPair('dog', 'chó'),
    WordPair('eat', 'ăn'),
    WordPair('fish', 'cá'),
    WordPair('good', 'tốt'),
    WordPair('happy', 'vui'),
    WordPair('house', 'nhà'),
    WordPair('ice', 'băng'),
    WordPair('jump', 'nhảy'),
    WordPair('key', 'chìa khóa'),
    WordPair('love', 'yêu'),
    WordPair('moon', 'mặt trăng'),
    WordPair('name', 'tên'),
    WordPair('open', 'mở'),
    WordPair('play', 'chơi'),
    WordPair('queen', 'nữ hoàng'),
    WordPair('run', 'chạy'),
    WordPair('sun', 'mặt trời'),
    // Level 2
    WordPair('table', 'bàn'),
    WordPair('umbrella', 'ô dù'),
    WordPair('voice', 'giọng nói'),
    WordPair('water', 'nước'),
    WordPair('yellow', 'vàng'),
    WordPair('zero', 'không'),
    WordPair('angry', 'tức giận'),
    WordPair('beautiful', 'đẹp'),
    WordPair('careful', 'cẩn thận'),
    WordPair('danger', 'nguy hiểm'),
    WordPair('early', 'sớm'),
    WordPair('famous', 'nổi tiếng'),
    WordPair('gentle', 'nhẹ nhàng'),
    WordPair('honest', 'trung thực'),
    WordPair('important', 'quan trọng'),
    WordPair('journey', 'hành trình'),
    WordPair('knowledge', 'kiến thức'),
    WordPair('language', 'ngôn ngữ'),
    WordPair('memory', 'ký ức'),
    WordPair('nature', 'thiên nhiên'),
    // Level 3
    WordPair('observe', 'quan sát'),
    WordPair('patient', 'kiên nhẫn'),
    WordPair('quality', 'chất lượng'),
    WordPair('reason', 'lý do'),
    WordPair('silence', 'im lặng'),
    WordPair('talent', 'tài năng'),
    WordPair('unique', 'độc đáo'),
    WordPair('valuable', 'có giá trị'),
    WordPair('wisdom', 'sự khôn ngoan'),
    WordPair('excellent', 'xuất sắc'),
    WordPair('freedom', 'tự do'),
    WordPair('grateful', 'biết ơn'),
    WordPair('harmony', 'hòa hợp'),
    WordPair('inspire', 'truyền cảm hứng'),
    WordPair('justice', 'công lý'),
    WordPair('kindness', 'lòng tốt'),
    WordPair('loyalty', 'lòng trung thành'),
    WordPair('miracle', 'phép màu'),
    WordPair('noble', 'cao quý'),
    WordPair('optimism', 'lạc quan'),
    // Level 4 — IELTS cơ bản
    WordPair('abandon', 'từ bỏ'),
    WordPair('abstract', 'trừu tượng'),
    WordPair('accelerate', 'tăng tốc'),
    WordPair('accurate', 'chính xác'),
    WordPair('achieve', 'đạt được'),
    WordPair('acknowledge', 'thừa nhận'),
    WordPair('acquire', 'thu được'),
    WordPair('adapt', 'thích nghi'),
    WordPair('adequate', 'đầy đủ'),
    WordPair('adjacent', 'liền kề'),
    WordPair('advocate', 'ủng hộ'),
    WordPair('affect', 'ảnh hưởng'),
    WordPair('aggregate', 'tổng hợp'),
    WordPair('allocate', 'phân bổ'),
    WordPair('ambiguous', 'mơ hồ'),
    WordPair('analyze', 'phân tích'),
    WordPair('anticipate', 'dự đoán'),
    WordPair('apparent', 'rõ ràng'),
    WordPair('approach', 'tiếp cận'),
    WordPair('appropriate', 'phù hợp'),
    // Level 5+
    WordPair('arbitrary', 'tùy tiện'),
    WordPair('assess', 'đánh giá'),
    WordPair('assume', 'giả định'),
    WordPair('attribute', 'quy cho'),
    WordPair('benefit', 'lợi ích'),
    WordPair('capacity', 'năng lực'),
    WordPair('category', 'danh mục'),
    WordPair('challenge', 'thách thức'),
    WordPair('circumstance', 'hoàn cảnh'),
    WordPair('collaborate', 'hợp tác'),
    WordPair('complex', 'phức tạp'),
    WordPair('concept', 'khái niệm'),
    WordPair('conclude', 'kết luận'),
    WordPair('consequence', 'hậu quả'),
    WordPair('considerable', 'đáng kể'),
    WordPair('consistent', 'nhất quán'),
    WordPair('constitute', 'cấu thành'),
    WordPair('context', 'bối cảnh'),
    WordPair('contrast', 'tương phản'),
    WordPair('contribute', 'đóng góp'),
  ];
}
