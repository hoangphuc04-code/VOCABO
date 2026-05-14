/// Models cho hệ thống kiểm tra tiếng Anh
/// Hỗ trợ đầy đủ các dạng câu hỏi trong đề thi chuẩn:
/// - Trắc nghiệm (Multiple Choice)
/// - Điền vào chỗ trống (Fill in the blank)
/// - Đọc hiểu (Reading Comprehension)
/// - Sắp xếp câu (Sentence Ordering)
/// - Tìm lỗi sai (Error Identification)
/// - Từ đồng nghĩa / trái nghĩa (Synonym / Antonym)
/// - Chia động từ (Verb Form)
/// - Hoàn thành đoạn văn (Cloze Test)

enum QuestionType {
  multipleChoice,       // Trắc nghiệm 4 đáp án
  fillInBlank,          // Điền vào chỗ trống
  readingComprehension, // Đọc hiểu đoạn văn
  errorIdentification,  // Tìm lỗi sai (A/B/C/D gạch chân)
  synonymAntonym,       // Đồng nghĩa / trái nghĩa
  verbForm,             // Chia động từ
  clozeTest,            // Điền vào đoạn văn (chọn từ)
  sentenceOrdering,     // Sắp xếp câu đúng thứ tự
  wordMatching,         // Nối từ với nghĩa
}

enum ExamType {
  quick,      // Nhanh: 10 câu, 5 phút
  standard,   // Chuẩn: 20 câu, 15 phút
  full,       // Đầy đủ: 40 câu, 30 phút
  ielts,      // IELTS style: 40 câu, 60 phút
  toeic,      // TOEIC style: 30 câu, 25 phút
  thpt,       // THPT Quốc gia: 50 câu, 60 phút
  custom,     // Tùy chỉnh
}

enum DifficultyLevel {
  easy,    // A1-A2
  medium,  // B1-B2
  hard,    // C1-C2
  mixed,   // Hỗn hợp
}

/// Một đáp án trong câu hỏi trắc nghiệm
class AnswerOption {
  final String label;   // A, B, C, D
  final String text;    // Nội dung đáp án
  final bool isCorrect;

  const AnswerOption({
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  factory AnswerOption.fromMap(Map<String, dynamic> m) => AnswerOption(
        label: m['label'] as String? ?? '',
        text: m['text'] as String? ?? '',
        isCorrect: m['isCorrect'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'text': text,
        'isCorrect': isCorrect,
      };
}

/// Một câu hỏi trong đề thi
class ExamQuestion {
  final String id;
  final QuestionType type;
  final int number;           // Số thứ tự câu
  final String instruction;   // Hướng dẫn (ví dụ: "Choose the best answer")
  final String questionText;  // Nội dung câu hỏi
  final String? passage;      // Đoạn văn (cho reading comprehension / cloze)
  final List<AnswerOption> options; // Các đáp án
  final String correctAnswer; // Đáp án đúng (label: A/B/C/D hoặc text)
  final String explanation;   // Giải thích đáp án
  final String? imageUrl;     // Ảnh minh họa (nếu có)
  final String? audioUrl;     // Audio (nếu có)
  final DifficultyLevel difficulty;
  final String? tag;          // Chủ đề / kỹ năng (grammar, vocabulary, reading...)
  final List<String>? wordParts; // Cho câu sắp xếp

  const ExamQuestion({
    required this.id,
    required this.type,
    required this.number,
    required this.instruction,
    required this.questionText,
    this.passage,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.imageUrl,
    this.audioUrl,
    this.difficulty = DifficultyLevel.medium,
    this.tag,
    this.wordParts,
  });

  factory ExamQuestion.fromMap(Map<String, dynamic> m, int number) {
    return ExamQuestion(
      id: m['id'] as String? ?? '',
      type: QuestionType.values.firstWhere(
        (t) => t.name == (m['type'] as String? ?? 'multipleChoice'),
        orElse: () => QuestionType.multipleChoice,
      ),
      number: number,
      instruction: m['instruction'] as String? ?? '',
      questionText: m['questionText'] as String? ?? '',
      passage: m['passage'] as String?,
      options: (m['options'] as List<dynamic>? ?? [])
          .map((o) => AnswerOption.fromMap(o as Map<String, dynamic>))
          .toList(),
      correctAnswer: m['correctAnswer'] as String? ?? '',
      explanation: m['explanation'] as String? ?? '',
      imageUrl: m['imageUrl'] as String?,
      audioUrl: m['audioUrl'] as String?,
      difficulty: DifficultyLevel.values.firstWhere(
        (d) => d.name == (m['difficulty'] as String? ?? 'medium'),
        orElse: () => DifficultyLevel.medium,
      ),
      tag: m['tag'] as String?,
      wordParts: m['wordParts'] != null
          ? List<String>.from(m['wordParts'] as List)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'number': number,
        'instruction': instruction,
        'questionText': questionText,
        if (passage != null) 'passage': passage,
        'options': options.map((o) => o.toMap()).toList(),
        'correctAnswer': correctAnswer,
        'explanation': explanation,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'difficulty': difficulty.name,
        if (tag != null) 'tag': tag,
        if (wordParts != null) 'wordParts': wordParts,
      };
}

/// Một phần (section) trong đề thi
class ExamSection {
  final String title;         // Tên phần (VD: "PHẦN I: NGỮ PHÁP")
  final String? description;  // Mô tả phần
  final List<ExamQuestion> questions;
  final int timeLimit;        // Giới hạn thời gian (giây), 0 = không giới hạn

  const ExamSection({
    required this.title,
    this.description,
    required this.questions,
    this.timeLimit = 0,
  });
}

/// Toàn bộ đề thi
class ExamPaper {
  final String id;
  final String title;
  final ExamType type;
  final DifficultyLevel difficulty;
  final List<ExamSection> sections;
  final int totalQuestions;
  final int timeLimitSeconds; // Tổng thời gian làm bài (giây)
  final DateTime createdAt;
  final String? topicId;      // Nếu thi theo chủ đề cụ thể
  final String? topicName;

  const ExamPaper({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.sections,
    required this.totalQuestions,
    required this.timeLimitSeconds,
    required this.createdAt,
    this.topicId,
    this.topicName,
  });

  List<ExamQuestion> get allQuestions =>
      sections.expand((s) => s.questions).toList();
}

/// Câu trả lời của người dùng
class UserAnswer {
  final String questionId;
  final String selectedAnswer; // Label đã chọn (A/B/C/D) hoặc text
  final bool isCorrect;
  final int timeSpentSeconds;  // Thời gian làm câu này

  const UserAnswer({
    required this.questionId,
    required this.selectedAnswer,
    required this.isCorrect,
    this.timeSpentSeconds = 0,
  });
}

/// Kết quả bài thi
class ExamResult {
  final String examId;
  final String examTitle;
  final ExamType examType;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int skippedAnswers;
  final int totalTimeSeconds;
  final double score;           // Điểm 0-10
  final double percentage;      // % đúng
  final Map<String, int> sectionScores; // Điểm từng phần
  final Map<String, double> skillScores; // Điểm theo kỹ năng (grammar, vocab...)
  final List<UserAnswer> answers;
  final List<ExamQuestion> questions; // Để hiển thị review
  final DateTime completedAt;
  final String? grade;          // A, B, C, D, F hoặc band score IELTS

  const ExamResult({
    required this.examId,
    required this.examTitle,
    required this.examType,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.skippedAnswers,
    required this.totalTimeSeconds,
    required this.score,
    required this.percentage,
    required this.sectionScores,
    required this.skillScores,
    required this.answers,
    required this.questions,
    required this.completedAt,
    this.grade,
  });

  String get gradeLabel {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  String get gradeEmoji {
    if (percentage >= 90) return '🏆';
    if (percentage >= 80) return '🌟';
    if (percentage >= 70) return '👍';
    if (percentage >= 60) return '😊';
    if (percentage >= 50) return '💪';
    return '📚';
  }

  String get feedbackMessage {
    if (percentage >= 90) return 'Xuất sắc! Bạn nắm vững kiến thức rất tốt!';
    if (percentage >= 80) return 'Rất tốt! Chỉ cần ôn thêm một chút nữa thôi!';
    if (percentage >= 70) return 'Khá tốt! Tiếp tục cố gắng nhé!';
    if (percentage >= 60) return 'Được rồi! Hãy ôn lại các phần còn yếu.';
    if (percentage >= 50) return 'Cần cố gắng thêm! Đừng nản lòng nhé.';
    return 'Hãy ôn tập lại từ đầu, bạn sẽ làm được!';
  }
}

/// Config cho đề thi tùy chỉnh
class ExamConfig {
  final ExamType type;
  final DifficultyLevel difficulty;
  final int questionCount;
  final int timeLimitMinutes;
  final List<QuestionType> questionTypes;
  final String? topicId;
  final String? topicName;
  final bool useLearnedWords; // Dùng từ đã học của user

  const ExamConfig({
    required this.type,
    required this.difficulty,
    required this.questionCount,
    required this.timeLimitMinutes,
    required this.questionTypes,
    this.topicId,
    this.topicName,
    this.useLearnedWords = false,
  });
}
