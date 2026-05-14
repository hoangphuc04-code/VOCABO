# 🐱 Meow AI - Tính năng mới

## 📋 Tổng quan

Meow AI đã được nâng cấp với các tính năng thông minh giúp người dùng học tiếng Anh hiệu quả hơn:

### ✨ Các tính năng chính

#### 1. 📊 Thu thập dữ liệu người dùng
- **Màn hình onboarding** (`UserGoalScreen`) thu thập:
  - Trình độ hiện tại (A1-C2)
  - Mục tiêu học tập và thời gian
  - Số phút học mỗi ngày
  - Khung giờ rảnh (sáng/chiều/tối/đêm)
  - Phong cách động viên (vui vẻ/nhẹ nhàng/nghiêm túc)

#### 2. 💬 Tin nhắn động viên tự động
- **MotivationService** gửi thông báo động viên:
  - Nhắc nhở học tập định kỳ (mỗi 4-6 giờ)
  - Cảnh báo streak sắp bị gãy
  - Tin nhắn cá nhân hóa theo phong cách người dùng
  - Badge thông báo trên AI chat bubble

#### 3. 📚 Xây dựng kế hoạch học tiếng Anh
- AI tự động tạo kế hoạch học theo:
  - Mục tiêu và thời gian của người dùng
  - Chia thành các mốc (milestones) cụ thể
  - Tự động thêm sự kiện vào calendar
  - Lưu vào Firestore để theo dõi tiến độ

#### 4. 📷 Đọc hình ảnh trong chat
- **Tính năng Vision AI**:
  - Chọn ảnh từ thư viện hoặc chụp mới
  - AI đọc và phân tích nội dung ảnh
  - Tự động phát hiện lịch/sự kiện trong ảnh
  - Thêm vào calendar nếu phát hiện thông tin lịch

#### 5. ⚠️ Phát hiện xung đột lịch
- **Conflict Detection**:
  - Tự động kiểm tra xung đột khi thêm sự kiện mới
  - Hiển thị dialog với 3 lựa chọn:
    1. **Ưu tiên sự kiện mới** → Lùi sự kiện cũ 1 tiếng
    2. **Ưu tiên sự kiện cũ** → Lùi sự kiện mới 1 tiếng
    3. **Xóa sự kiện cũ** → Giữ sự kiện mới
  - UI trực quan với màu sắc phân biệt

---

## 🗂️ Cấu trúc file mới

```
lib/
├── data/
│   ├── models/
│   │   ├── study_plan_model.dart       ✅ Model kế hoạch học tập
│   │   ├── study_history_model.dart    ✅ Model lịch sử học tập
│   │   └── user_model.dart             ✅ Cập nhật với thông tin mục tiêu
│   └── services/
│       ├── meow_ai_service.dart        ✅ Nâng cấp: Vision AI, Study Plan, Conflict Check
│       └── motivation_service.dart     ✅ Service gửi tin nhắn động viên
├── views/
│   └── onboarding/
│       └── user_goal_screen.dart       ✅ Màn hình thu thập mục tiêu
└── AI/
    ├── ai_planner_screen.dart          ✅ Nâng cấp: Image upload, Conflict handling
    └── ai_chat_bubble.dart             ✅ Thêm badge thông báo
```

---

## 🚀 Cách sử dụng

### 1. Thiết lập mục tiêu học tập

```dart
// Từ màn hình settings hoặc home
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const UserGoalScreen()),
);
```

### 2. Chat với Meow AI

```dart
// Gửi tin nhắn văn bản
await MeowAIService.askMeow('Lập kế hoạch học IELTS 6 tháng');

// Gửi tin nhắn kèm ảnh
await MeowAIService.askMeowWithImage(
  'Đọc lịch trong ảnh này',
  imageFile,
);
```

### 3. Kiểm tra xung đột lịch

```dart
final conflicts = await MeowAIService.checkConflicts(newEvent);
if (conflicts.isNotEmpty) {
  // Hiển thị dialog xử lý xung đột
  _showConflictDialog(newEvent, conflicts.first);
}
```

### 4. Gửi tin nhắn động viên

```dart
// Tự động gửi khi mở app
await MotivationService.sendInAppMotivation();

// Kiểm tra và gửi nhắc nhở học tập
await MotivationService.checkAndSendStudyReminder();
```

---

## 🎨 UI/UX Highlights

### Màn hình onboarding
- **5 bước** thu thập thông tin
- Progress bar hiển thị tiến độ
- Animation mượt mà giữa các bước
- Gradient theme nhất quán

### Chat với AI
- **Bubble chat** với avatar Meow
- **Image preview** trước khi gửi
- **Typing indicator** khi AI đang trả lời
- **Bottom sheet** xác nhận thêm lịch/kế hoạch

### Conflict Dialog
- **3 options** rõ ràng với màu sắc phân biệt
- **Event cards** hiển thị thông tin chi tiết
- **Numbered buttons** dễ chọn

---

## 📊 Firestore Collections

### `users/{uid}`
```json
{
  "currentLevel": "A1",
  "targetLevel": "B2",
  "targetDate": "2026-10-24T00:00:00Z",
  "dailyGoalMinutes": 30,
  "freeTimeSlots": ["morning", "evening"],
  "motivationStyle": "fun",
  "notificationsEnabled": true
}
```

### `study_plans/{planId}`
```json
{
  "uid": "user123",
  "title": "Kế hoạch học IELTS 6 tháng",
  "targetLevel": "B2",
  "hoursPerWeek": 10,
  "milestones": [
    {
      "title": "Tháng 1: Nền tảng",
      "dueDate": "2026-05-24T00:00:00Z",
      "tasks": ["Học 10 từ/ngày", "Nghe podcast"],
      "isCompleted": false
    }
  ],
  "createdAt": "2026-04-24T10:00:00Z",
  "isActive": true
}
```

### `user_notifications/{notifId}`
```json
{
  "uid": "user123",
  "title": "😺 Meow nhắc bạn!",
  "body": "Hôm nay bạn đã học chưa? Mèo đang chờ đấy!",
  "type": "motivation",
  "isRead": false,
  "createdAt": "2026-04-24T08:00:00Z"
}
```

### `events/{eventId}`
```json
{
  "uid": "user123",
  "title": "Học tiếng Anh - Buổi sáng",
  "description": "Học từ vựng và ngữ pháp",
  "date": "2026-04-25T00:00:00Z",
  "time": "07:00",
  "completed": false,
  "source": "meow_ai",
  "createdAt": "2026-04-24T10:00:00Z"
}
```

---

## 🔧 Dependencies mới

```yaml
dependencies:
  image_picker: ^1.0.7                    # Chọn ảnh
  flutter_local_notifications: ^17.2.2    # Push notifications (tương lai)
```

---

## 🎯 Roadmap tiếp theo

- [ ] Push notifications thực sự (FCM)
- [ ] Gamification: XP, badges, leaderboard
- [ ] Social features: chia sẻ kế hoạch, học cùng bạn bè
- [ ] Voice chat với Meow AI
- [ ] Offline mode với local AI

---

## 📝 Ghi chú kỹ thuật

### Vision AI Model
- **Model**: `meta-llama/llama-4-scout-17b-16e-instruct`
- **Provider**: Groq API (free tier)
- **Hỗ trợ**: JPEG, PNG
- **Max size**: 1024x1024 (auto resize)

### Conflict Detection Algorithm
- Kiểm tra sự kiện trong cùng ngày
- Coi mỗi sự kiện kéo dài 60 phút
- Xung đột nếu khoảng cách < 60 phút

### Motivation Timing
- Gửi mỗi 4-6 giờ (tùy loại)
- Không gửi nếu đã học trong ngày
- Cá nhân hóa theo `motivationStyle`

---

## 🐛 Known Issues

1. **Vision AI**: Đôi khi không nhận diện chính xác lịch viết tay
2. **Conflict**: Chỉ kiểm tra trong cùng ngày, chưa xử lý multi-day events
3. **Notifications**: Chưa có push notifications thực sự (chỉ in-app)

---

## 👨‍💻 Hướng dẫn phát triển

### Test Vision AI
```dart
final file = File('path/to/image.jpg');
final response = await MeowAIService.askMeowWithImage(
  'Đọc lịch trong ảnh',
  file,
);
print(response.text);
```

### Test Conflict Detection
```dart
final newEvent = CalendarEventData(
  title: 'Test Event',
  date: DateTime.now(),
  time: TimeComponents(hour: 10, minute: 0),
  description: 'Test',
);
final conflicts = await MeowAIService.checkConflicts(newEvent);
print('Found ${conflicts.length} conflicts');
```

---

**Made with 💜 by Meow AI Team**
