class UserModel {
  String uid;
  String name;
  String email;
  String phone;
  String address;
  String avatar;

  // Thông tin học tập
  String currentLevel;       // A1, A2, B1, B2, C1, C2
  String targetLevel;        // Mục tiêu
  DateTime? targetDate;      // Ngày muốn đạt mục tiêu
  int dailyGoalMinutes;      // Số phút học mỗi ngày
  List<String> freeTimeSlots; // Khung giờ rảnh: ['morning', 'afternoon', 'evening']
  int streak;
  int wordsLearned;
  double progress;
  bool notificationsEnabled;
  String? motivationStyle;   // 'gentle', 'strict', 'fun'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.avatar,
    this.currentLevel = 'A1',
    this.targetLevel = 'B2',
    this.targetDate,
    this.dailyGoalMinutes = 30,
    this.freeTimeSlots = const ['evening'],
    this.streak = 0,
    this.wordsLearned = 0,
    this.progress = 0.0,
    this.notificationsEnabled = true,
    this.motivationStyle = 'fun',
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'avatar': avatar,
      'currentLevel': currentLevel,
      'targetLevel': targetLevel,
      'targetDate': targetDate?.toIso8601String(),
      'dailyGoalMinutes': dailyGoalMinutes,
      'freeTimeSlots': freeTimeSlots,
      'streak': streak,
      'wordsLearned': wordsLearned,
      'progress': progress,
      'notificationsEnabled': notificationsEnabled,
      'motivationStyle': motivationStyle,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      avatar: json['avatar'] ?? '',
      currentLevel: json['currentLevel'] ?? 'A1',
      targetLevel: json['targetLevel'] ?? 'B2',
      targetDate: json['targetDate'] != null
          ? DateTime.tryParse(json['targetDate'])
          : null,
      dailyGoalMinutes: json['dailyGoalMinutes'] ?? 30,
      freeTimeSlots: List<String>.from(json['freeTimeSlots'] ?? ['evening']),
      streak: json['streak'] ?? 0,
      wordsLearned: json['wordsLearned'] ?? 0,
      progress: (json['progress'] ?? 0.0).toDouble(),
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      motivationStyle: json['motivationStyle'] ?? 'fun',
    );
  }
}
