# 💎❤️ Hệ thống Diamond & Heart - Tài liệu đầy đủ

## 📋 Tổng quan

Hệ thống Diamond & Heart được thiết kế giống Duolingo, tạo động lực học tập và gamification cho ứng dụng Vocabo.

### ✨ Tính năng chính

#### 1. ❤️ Heart System (Tim)
- **Số lượng tối đa**: 5 tim
- **Tiêu hao**: Mất 1 tim khi nhấn "Không nhớ" trong flashcard
- **Hồi phục tự động**: 1 tim mỗi 30 phút
- **Chặn học**: Không thể học flashcard khi hết tim

#### 2. 💎 Diamond System (Kim cương)
- **Kiếm Diamond**: Điểm danh hàng ngày
- **Dùng Diamond**: Mua tim để tiếp tục học
- **Streak bonus**: Càng điểm danh liên tục, càng nhận nhiều Diamond

#### 3. 📅 Điểm danh hàng ngày
- **Floating button**: Hiển thị ở màn hình chính
- **Streak tracking**: Theo dõi chuỗi ngày điểm danh
- **Rewards**:
  - Ngày thường: 5💎
  - 3 ngày liên tiếp: 8💎
  - 7 ngày liên tiếp: 12💎
  - 14 ngày liên tiếp: 15💎
  - 30 ngày liên tiếp: 20💎

#### 4. 🛒 Cửa hàng Tim
- **Mua 1 tim**: 5💎
- **Mua đầy tim (5 tim)**: 20💎 (tốt nhất)
- **Hiển thị thời gian hồi phục**: Countdown đến tim tiếp theo

---

## 📁 Cấu trúc file

### Files mới tạo:

```
lib/
├── data/
│   └── services/
│       └── currency_service.dart          ✅ Service quản lý Diamond & Heart
├── views/
│   ├── widgets/
│   │   └── currency_bar.dart              ✅ Widget hiển thị Hearts & Diamonds
│   ├── shop/
│   │   └── heart_shop_screen.dart         ✅ Màn hình cửa hàng mua tim
│   └── checkin/
│       ├── daily_checkin_screen.dart      ✅ Dialog điểm danh hàng ngày
│       └── checkin_bubble.dart            ✅ Floating button điểm danh
```

### Files đã cập nhật:

```
lib/
├── views/
│   ├── home/
│   │   └── home_screen.dart               ✅ Thêm CheckinBubble, CurrencyWidget
│   └── flashcard/
│       └── learn_screen.dart              ✅ Tích hợp Heart system
└── pubspec.yaml                           ✅ Thêm confetti package
```

---

## 🗄️ Firestore Schema

### `users/{uid}` - Thêm fields mới:

```json
{
  "hearts": 5,                    // Số tim hiện tại (0-5)
  "diamonds": 10,                 // Số diamond hiện tại
  "lastHeartLostAt": Timestamp,   // Thời điểm mất tim gần nhất
  "lastCheckinDate": "2026-04-24", // Ngày điểm danh gần nhất (YYYY-MM-DD)
  "checkinStreak": 7,             // Chuỗi ngày điểm danh liên tiếp
  "lastCheckinAt": Timestamp      // Timestamp điểm danh gần nhất
}
```

---

## 🎮 Luồng hoạt động

### 1. Học Flashcard

```
User mở Learn Screen
  ↓
Hiển thị Hearts trên AppBar (❤️❤️❤️❤️❤️)
  ↓
User xem từ vựng
  ↓
┌─────────────────────────────────────┐
│ User nhấn "Đã nhớ" → Không mất tim  │
│ User nhấn "Không nhớ" → Mất 1 tim   │
└─────────────────────────────────────┘
  ↓
Nếu hearts = 0 → Hiện dialog "Hết tim"
  ↓
┌──────────────────────────────────────┐
│ Option 1: Mua tim bằng Diamond       │
│ Option 2: Thoát và chờ hồi phục      │
└──────────────────────────────────────┘
```

### 2. Điểm danh hàng ngày

```
User nhấn Checkin Bubble (📅)
  ↓
Hiện dialog điểm danh
  ↓
Hiển thị lịch 7 ngày (✓ = đã điểm danh)
  ↓
User nhấn "Điểm danh ngay!"
  ↓
┌────────────────────────────────────────┐
│ Kiểm tra đã điểm danh hôm nay chưa?    │
│ - Đã điểm danh → Hiện thông báo        │
│ - Chưa → Tính streak và tặng Diamond  │
└────────────────────────────────────────┘
  ↓
Confetti animation 🎉
  ↓
Hiển thị số Diamond nhận được + Streak
```

### 3. Mua Tim

```
User hết tim → Nhấn "Mua Tim"
  ↓
Mở Heart Shop Screen
  ↓
Hiển thị:
- Tài sản hiện tại (Hearts + Diamonds)
- 2 options mua tim
- Thời gian hồi phục tự động
- Cách kiếm Diamond
  ↓
User chọn mua
  ↓
┌────────────────────────────────────────┐
│ Kiểm tra đủ Diamond không?             │
│ - Đủ → Trừ Diamond, cộng Hearts        │
│ - Không đủ → Hiện thông báo lỗi        │
└────────────────────────────────────────┘
  ↓
Cập nhật UI realtime
```

---

## 🔧 API Reference

### CurrencyService

#### Static Methods:

```dart
// Lấy dữ liệu currency realtime
Stream<Map<String, dynamic>> currencyStream()

// Lấy dữ liệu một lần
Future<Map<String, dynamic>> getCurrency()

// Tiêu hao 1 heart
Future<int> loseHeart()

// Kiểm tra và hồi phục heart theo thời gian
Future<void> checkHeartRecovery()

// Mua 1 heart (5💎)
Future<({bool success, String message})> buyHeart()

// Mua full hearts (20💎)
Future<({bool success, String message})> buyFullHearts()

// Điểm danh hàng ngày
Future<CheckinResult> dailyCheckin()

// Kiểm tra đã điểm danh hôm nay chưa
Future<bool> hasCheckedInToday()

// Khởi tạo currency cho user mới
Future<void> initCurrencyIfNeeded()

// Thời gian hồi phục heart tiếp theo
Future<Duration?> nextHeartRecoveryIn()

// Lịch sử điểm danh 7 ngày
Future<List<bool>> getCheckinHistory7Days()
```

#### Constants:

```dart
static const int maxHearts = 5;
static const int heartRefillCost = 5;      // 5💎 = 1❤️
static const int fullRefillCost = 20;      // 20💎 = 5❤️
static const int heartRecoverMinutes = 30; // 30 phút/tim
```

---

## 🎨 UI Components

### 1. CurrencyBar (AppBar widget)
```dart
const CurrencyBar()
```
- Hiển thị Hearts và Diamonds
- Nhấn vào Hearts → Mở Heart Shop
- Realtime update từ Firestore

### 2. CheckinBubble (Floating button)
```dart
const CheckinBubble()
```
- Floating button có thể kéo
- Badge "MỚI" khi chưa điểm danh
- Pulse animation khi chưa điểm danh
- Màu xám khi đã điểm danh

### 3. DailyCheckinScreen (Dialog)
```dart
const DailyCheckinScreen()
```
- Lịch 7 ngày với checkmarks
- Confetti animation khi điểm danh thành công
- Hiển thị Diamond nhận được + Streak
- Scale animation khi mở

### 4. HeartShopScreen (Full screen)
```dart
const HeartShopScreen()
```
- Wallet card hiển thị tài sản
- 2 options mua tim
- Recovery info với countdown
- Cách kiếm Diamond

---

## 🎯 Gamification Strategy

### Tạo động lực học tập:

1. **Scarcity (Khan hiếm)**
   - Giới hạn 5 tim
   - Hồi phục chậm (30 phút/tim)
   - Tạo cảm giác quý giá

2. **Reward (Phần thưởng)**
   - Điểm danh hàng ngày → Diamond
   - Streak càng cao → Reward càng lớn
   - Tạo thói quen quay lại app

3. **Progress (Tiến độ)**
   - Streak tracking
   - Lịch 7 ngày trực quan
   - Cảm giác thành tựu

4. **Choice (Lựa chọn)**
   - Mua tim ngay hoặc chờ hồi phục
   - Học cẩn thận hoặc học nhanh
   - Tạo chiến lược cá nhân

---

## 📊 Analytics & Metrics

### Metrics cần theo dõi:

1. **Heart Usage**
   - Số lần mất tim/ngày
   - Tỷ lệ "Đã nhớ" vs "Không nhớ"
   - Thời gian trung bình giữa các lần mất tim

2. **Diamond Economy**
   - Số Diamond kiếm được/ngày
   - Số Diamond tiêu/ngày
   - Tỷ lệ mua tim vs chờ hồi phục

3. **Checkin Behavior**
   - Tỷ lệ điểm danh hàng ngày
   - Streak trung bình
   - Thời gian điểm danh phổ biến

4. **Retention**
   - Tỷ lệ quay lại sau khi hết tim
   - Tỷ lệ duy trì streak > 7 ngày
   - Tỷ lệ mua tim lần đầu

---

## 🚀 Cách sử dụng

### 1. Khởi tạo cho user mới

```dart
// Trong main.dart hoặc auth flow
await CurrencyService.initCurrencyIfNeeded();
```

### 2. Hiển thị Hearts & Diamonds

```dart
// Trong AppBar
appBar: AppBar(
  actions: [
    const CurrencyBar(),
  ],
),
```

### 3. Tích hợp vào Flashcard

```dart
// Khi user nhấn "Không nhớ"
final remaining = await CurrencyService.loseHeart();
if (remaining == 0) {
  _showNoHeartsDialog();
}
```

### 4. Thêm Checkin Bubble

```dart
// Trong HomeScreen
Stack(
  children: [
    // ... other widgets
    const CheckinBubble(),
  ],
)
```

---

## 🐛 Troubleshooting

### Hearts không hồi phục?
```dart
// Gọi trong initState hoặc onResume
await CurrencyService.checkHeartRecovery();
```

### Streak bị reset?
- Kiểm tra `lastCheckinDate` format (YYYY-MM-DD)
- Đảm bảo timezone đúng
- Kiểm tra logic tính streak trong `dailyCheckin()`

### Diamond không cộng?
- Kiểm tra transaction trong Firestore
- Xem logs trong `dailyCheckin()`
- Verify `checkinStreak` được cập nhật

---

## 🔮 Future Enhancements

- [ ] Push notification nhắc điểm danh
- [ ] Leaderboard streak
- [ ] Thêm cách kiếm Diamond (hoàn thành bài test, review...)
- [ ] Power-ups (2x Diamond, unlimited hearts...)
- [ ] Gifting system (tặng Diamond cho bạn bè)
- [ ] Seasonal events (double Diamond weekends)
- [ ] Achievement badges
- [ ] Heart recovery speed boost

---

## 📝 Notes

- **Confetti package**: Dùng cho animation điểm danh
- **Realtime updates**: Tất cả currency data sync realtime qua Firestore streams
- **Offline support**: Cần thêm local cache cho offline mode
- **Security**: Cần thêm Cloud Functions để validate transactions

---

**Status**: ✅ **HOÀN THÀNH**

**Tested**: ✅ Compile thành công, không có lỗi nghiêm trọng

**Ready for**: 🚀 Testing & Deployment

---

Made with 💜 by Vocabo Team
