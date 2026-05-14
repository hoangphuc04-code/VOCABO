import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho kế hoạch học tập được AI tạo ra
class StudyPlanModel {
  final String id;
  final String uid;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String targetLevel; // A1, A2, B1, B2, C1, C2
  final int hoursPerWeek;
  final List<StudyMilestone> milestones;
  final DateTime createdAt;
  final bool isActive;
  final String? aiGeneratedPrompt;

  StudyPlanModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.targetLevel,
    required this.hoursPerWeek,
    required this.milestones,
    required this.createdAt,
    this.isActive = true,
    this.aiGeneratedPrompt,
  });

  factory StudyPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyPlanModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      targetLevel: data['targetLevel'] ?? 'A1',
      hoursPerWeek: data['hoursPerWeek'] ?? 5,
      milestones: (data['milestones'] as List<dynamic>?)
              ?.map((m) => StudyMilestone.fromMap(m))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      aiGeneratedPrompt: data['aiGeneratedPrompt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'targetLevel': targetLevel,
      'hoursPerWeek': hoursPerWeek,
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'aiGeneratedPrompt': aiGeneratedPrompt,
    };
  }
}

/// Mốc thời gian trong kế hoạch học
class StudyMilestone {
  final String title;
  final String description;
  final DateTime dueDate;
  final List<String> tasks;
  final bool isCompleted;

  StudyMilestone({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.tasks,
    this.isCompleted = false,
  });

  factory StudyMilestone.fromMap(Map<String, dynamic> map) {
    return StudyMilestone(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      tasks: List<String>.from(map['tasks'] ?? []),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'tasks': tasks,
      'isCompleted': isCompleted,
    };
  }
}
