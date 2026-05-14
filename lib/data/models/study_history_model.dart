import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lưu lịch sử học tập của người dùng
class StudyHistoryModel {
  final String id;
  final String uid;
  final DateTime date;
  final int wordsStudied;
  final int minutesStudied;
  final String activityType; // 'flashcard', 'test', 'review', 'grammar'
  final int score;

  StudyHistoryModel({
    required this.id,
    required this.uid,
    required this.date,
    required this.wordsStudied,
    required this.minutesStudied,
    required this.activityType,
    required this.score,
  });

  factory StudyHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyHistoryModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      wordsStudied: data['wordsStudied'] ?? 0,
      minutesStudied: data['minutesStudied'] ?? 0,
      activityType: data['activityType'] ?? 'flashcard',
      score: data['score'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'date': Timestamp.fromDate(date),
      'wordsStudied': wordsStudied,
      'minutesStudied': minutesStudied,
      'activityType': activityType,
      'score': score,
    };
  }
}
