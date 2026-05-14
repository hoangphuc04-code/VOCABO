# 🏠 Mini House System - Tài liệu đầy đủ

## 📋 Tổng quan

Hệ thống Mini House được thiết kế theo phong cách **Animal Crossing** — trang trí phòng, nuôi pet, mời bạn bè thăm nhà.

---

## ✨ Tính năng chính

### 1. 🏠 Trang trí phòng
- **Góc nhìn isometric 2.5D** với grid 8x6
- **Giấy dán tường**: 7 loại (trắng, hồng, xanh, gỗ, gạch, hoa văn, ngôi sao)
- **Sàn nhà**: 5 loại (gạch xanh, gỗ, đá cẩm thạch, thảm, cỏ)
- **Nội thất**: Giường, sofa, bàn, kệ sách, tủ, TV, piano...
- **Trang trí**: Cây cảnh, đèn, tranh, đồng hồ, thảm, đèn dây...
- **Drag & drop** để đặt vật phẩm
- **Xoay** vật phẩm 90°, 180°, 270°
- **Edit mode** để chỉnh sửa

### 2. 🐾 Nuôi Pet
- **4 loại pet**: Mèo 🐱, Chó 🐶, Thỏ 🐰, Hamster 🐹
- **Chỉ số**:
  - **Hunger** (No bụng): 0-100, giảm 5/giờ
  - **Happiness** (Hạnh phúc): 0-100, giảm 3/giờ
  - **Level & XP**: Tăng khi cho ăn/chơi
- **Tương tác**:
  - **Cho ăn** 🍖: +30 hunger, +10 happiness, +5 XP (cooldown 30 phút)
  - **Chơi cùng** 🎾: +20 happiness, +10 XP (cooldown 15 phút)
  - **Đặt tên** pet tùy ý
- **Mood emoji**: 😸 (vui) → 😺 (bình thường) → 😿 (buồn) → 😾 (rất buồn)
- **Pet bounce animation** trong phòng

### 3. 🪙 Gold Coin Economy
- **Kiếm coin**: Chơi mini games (10-300 coin/màn tuỳ level & stars)
- **Tiêu coin**: Mua vật phẩm trang trí (30-300 coin)
- **Giá vật phẩm**:
  - Giấy dán tường: 50-150 coin
  - Sàn nhà: 60-100 coin
  - Nội thất: 80-300 coin
  - Trang trí: 30-100 coin
  - Pet mới: 150-200 coin

### 4. 👥 Thăm nhà bạn bè
- **Danh sách bạn bè** có nhà
- **Xem nhà** của bạn bè (read-only)
- **Ghi nhận lượt thăm** (visitors list)
- **Xem pet** của bạn bè

### 5. 👧 Nhân vật di chuyển
- **Tap vào sàn** để di chuyển nhân vật
- **Smooth animation** với AnimatedPositioned
- **Shadow** dưới chân nhân vật

---

## 📁 Cấu trúc file

### Files mới tạo:

```
lib/
├── data/
│   └── services/
│       └── house_service.dart          ✅ Service quản lý nhà, pet, vật phẩm
└── views/
    └── house/
        ├── house_screen.dart           ✅ Màn hình chính (phòng + pet + character)
        ├── house_shop_screen.dart      ✅ Cửa hàng mua đồ
        ├── pet_screen.dart             ✅ Màn hình tương tác pet
        └── visit_friends_screen.dart   ✅ Danh sách bạn bè để thăm nhà
```

### Files đã cập nhật:

```
lib/
├── views/
│   └── home/
│       └── home_screen.dart            ✅ Thêm button House, _MiniHousePreview
└── data/
    └── services/
        └── game_service.dart           ✅ Đã có sẵn coin system
```

---

## 🗄️ Firestore Schema

### `houses/{uid}`

```json
{
  "wallpaper": "wall_white",
  "floorType": "floor_tile_blue",
  "placedItems": [
    {
      "instanceId": "bed_basic_1234567890",
      "itemId": "bed_basic",
      "gridX": 5,
      "gridY": 1,
      "rotation": 0
    }
  ],
  "ownedItems": ["wall_white", "floor_tile_blue", "bed_basic", "sofa"],
  "pet": {
    "type": "cat",
    "name": "Mèo con",
    "hunger": 70,
    "happiness": 80,
    "level": 1,
    "xp": 0,
    "lastFedAt": "2026-04-24T10:00:00Z",
    "lastPlayedAt": "2026-04-24T09:30:00Z",
    "lastDecayAt": "2026-04-24T08:00:00Z"
  },
  "visitors": [
    {
      "uid": "friend123",
      "name": "Bạn A",
      "photo": "https://...",
      "visitedAt": "2026-04-24T11:00:00Z"
    }
  ]
}
```

### `users/{uid}` — Thêm field:

```json
{
  "coins": 150,
  "totalCoinsEarned": 500
}
```

---

## 🎮 Luồng hoạt động

### 1. Vào nhà lần đầu

```
User nhấn button "Nhà" trong MenuSection
  ↓
HouseService.initHouseIfNeeded()
  ↓
Tạo house document với:
- Tường trắng (default)
- Sàn gạch xanh (default)
- 1 giường cơ bản
- Pet mèo mặc định
  ↓
Hiển thị phòng với grid 8x6
```

### 2. Mua vật phẩm

```
User nhấn "Cửa hàng" trong HouseScreen
  ↓
Mở HouseShopScreen với 5 tabs
  ↓
User chọn vật phẩm → Nhấn "Mua"
  ↓
Kiểm tra đủ coin không?
  ↓
┌────────────────────────────────────┐
│ Đủ → Trừ coin, thêm vào ownedItems │
│ Không đủ → Hiện thông báo lỗi      │
└────────────────────────────────────┘
  ↓
Nếu là tường/sàn → Nhấn "Áp dụng"
Nếu là nội thất → Nhấn "Đặt vào phòng"
```

### 3. Trang trí phòng

```
User bật Edit Mode (icon ✏️)
  ↓
Grid hiển thị border trắng
  ↓
Tap vào vật phẩm → Hiện overlay:
- Xoay (rotate 90°)
- Xoá (remove khỏi phòng)
- Xong (thoát edit mode)
  ↓
Lưu vào Firestore realtime
```

### 4. Nuôi Pet

```
User nhấn vào Pet trong bottom bar
  ↓
Mở PetScreen
  ↓
Hiển thị:
- Pet emoji với bounce animation
- Mood emoji (😸/😺/😿/😾)
- Stats bars (hunger, happiness)
- Level & XP progress
  ↓
User chọn hành động:
┌──────────────────────────────────────┐
│ Cho ăn → +30 hunger, +10 happiness   │
│ Chơi cùng → +20 happiness            │
│ Đặt tên → Đổi tên pet                │
└──────────────────────────────────────┘
  ↓
Pet bounce animation + message
```

### 5. Thăm nhà bạn bè

```
User nhấn "Thăm bạn" (icon 👥)
  ↓
Mở VisitFriendsScreen
  ↓
Hiển thị danh sách bạn bè + pet của họ
  ↓
User nhấn "Thăm" → Mở HouseScreen(ownerUid: friendUid)
  ↓
Hiển thị nhà của bạn (read-only, không edit được)
  ↓
Ghi nhận lượt thăm vào visitors array
```

---

## 🎨 UI/UX Highlights

### House Screen
- **Isometric grid** 8x6 với checkerboard pattern
- **Wall background** với pattern/emoji tuỳ loại
- **Floating AppBar** với nút Edit, Shop, Visit
- **Bottom bar** hiển thị pet stats + coins + visitors
- **Edit overlay** với 3 nút: Xoay, Xoá, Xong
- **Character** di chuyển khi tap vào sàn
- **Pet** bounce animation liên tục

### House Shop
- **5 tabs**: Tường, Sàn, Nội thất, Trang trí, Pet
- **Grid layout** 2 cột
- **Badge**: "Đang dùng" (xanh), "Đã có" (xanh nhạt)
- **Action buttons**: Mua / Áp dụng / Đặt vào phòng
- **Coin display** trên AppBar realtime

### Pet Screen
- **Pet emoji lớn** với bounce animation khi tương tác
- **Mood bubble** hiển thị cảm xúc
- **Stats bars** với icon + progress bar
- **Level card** với gradient purple
- **4 action buttons**: Cho ăn, Chơi, Tắm (coming soon), Thuốc (coming soon)
- **Message feedback** khi tương tác

### Visit Friends
- **Friend cards** với avatar + pet info
- **Visit button** màu cam
- **Empty state** khi chưa có bạn

---

## 🛒 Catalogue vật phẩm

### Wallpapers (7 loại):
| ID | Tên | Emoji | Giá | Mô tả |
|----|-----|-------|-----|-------|
| wall_white | Tường trắng | 🟫 | 0 | Mặc định |
| wall_pink | Tường hồng | 🌸 | 50 | Dễ thương |
| wall_blue | Tường xanh | 💙 | 50 | Dịu mát |
| wall_wood | Tường gỗ | 🪵 | 80 | Ấm áp |
| wall_brick | Tường gạch | 🧱 | 100 | Vintage |
| wall_floral | Hoa văn | 🌺 | 120 | Hoa văn |
| wall_stars | Ngôi sao | ⭐ | 150 | Lung linh |

### Floors (5 loại):
| ID | Tên | Emoji | Giá |
|----|-----|-------|-----|
| floor_tile_blue | Gạch xanh | 🔷 | 0 |
| floor_wood | Sàn gỗ | 🪵 | 60 |
| floor_marble | Đá cẩm thạch | ⬜ | 100 |
| floor_carpet | Thảm | 🟥 | 80 |
| floor_grass | Cỏ xanh | 🌿 | 90 |

### Furniture (9 loại):
| ID | Tên | Emoji | Giá |
|----|-----|-------|-----|
| bed_basic | Giường cơ bản | 🛏️ | 0 |
| bed_fancy | Giường sang | 🛏️ | 150 |
| sofa | Ghế sofa | 🛋️ | 120 |
| table_coffee | Bàn trà | 🪑 | 80 |
| bookshelf | Kệ sách | 📚 | 100 |
| desk | Bàn học | 🖥️ | 130 |
| wardrobe | Tủ quần áo | 🚪 | 110 |
| tv | TV | 📺 | 200 |
| piano | Đàn piano | 🎹 | 300 |

### Decorations (10 loại):
| ID | Tên | Emoji | Giá |
|----|-----|-------|-----|
| plant_small | Cây nhỏ | 🌱 | 30 |
| plant_big | Cây lớn | 🌿 | 60 |
| lamp | Đèn | 💡 | 50 |
| painting | Tranh | 🖼️ | 70 |
| globe | Quả địa cầu | 🌍 | 90 |
| clock | Đồng hồ | 🕐 | 60 |
| rug | Thảm tròn | ⭕ | 80 |
| fairy_lights | Đèn dây | ✨ | 100 |
| radio | Radio | 📻 | 70 |
| flowers | Bình hoa | 💐 | 40 |

### Pets (3 loại):
| ID | Tên | Emoji | Giá |
|----|-----|-------|-----|
| pet_dog | Chó cún | 🐶 | 200 |
| pet_rabbit | Thỏ bông | 🐰 | 180 |
| pet_hamster | Chuột hamster | 🐹 | 150 |

**Tổng**: 34 vật phẩm

---

## 🔧 API Reference

### HouseService

```dart
// Stream dữ liệu nhà realtime
Stream<HouseData> houseStream([String? uid])

// Lấy dữ liệu nhà một lần
Future<HouseData> getHouse([String? uid])

// Khởi tạo nhà cho user mới
Future<void> initHouseIfNeeded()

// Đặt vật phẩm vào phòng
Future<bool> placeItem(PlacedItem item)

// Xoá vật phẩm khỏi phòng
Future<void> removeItem(String instanceId)

// Đổi giấy dán tường
Future<void> setWallpaper(String itemId)

// Đổi sàn nhà
Future<void> setFloor(String itemId)

// Mua vật phẩm
Future<ShopResult> buyItem(HouseItem item)

// Cho pet ăn
Future<PetFeedResult> feedPet()

// Chơi với pet
Future<PetFeedResult> playWithPet()

// Đặt tên pet
Future<void> namePet(String name)

// Thăm nhà bạn bè
Future<void> visitHouse(String ownerUid)

// Decay pet stats theo thời gian
Future<void> decayPetStats()
```

---

## 🎯 Gamification Strategy

### Tạo động lực:

1. **Collection (Sưu tầm)**
   - 34 vật phẩm để unlock
   - Mỗi vật phẩm có giá khác nhau
   - Tạo mục tiêu dài hạn

2. **Customization (Cá nhân hoá)**
   - Trang trí phòng theo sở thích
   - Đặt tên pet
   - Thể hiện cá tính

3. **Social (Xã hội)**
   - Thăm nhà bạn bè
   - So sánh trang trí
   - Visitors list (khoe)

4. **Pet Care (Chăm sóc)**
   - Nuôi pet như Tamagotchi
   - Tạo trách nhiệm
   - Emotional attachment

5. **Progression (Tiến độ)**
   - Pet level up
   - Unlock vật phẩm mới
   - Cảm giác thành tựu

---

## 🚀 Cách sử dụng

### 1. Vào nhà

```dart
// Từ home screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const HouseScreen()),
);
```

### 2. Mua vật phẩm

```dart
final result = await HouseService.buyItem(item);
if (result.success) {
  // Đã mua thành công
}
```

### 3. Đặt vật phẩm

```dart
final placed = PlacedItem(
  instanceId: 'sofa_${DateTime.now().millisecondsSinceEpoch}',
  itemId: 'sofa',
  gridX: 3,
  gridY: 2,
  rotation: 90,
);
await HouseService.placeItem(placed);
```

### 4. Cho pet ăn

```dart
final result = await HouseService.feedPet();
print(result.message); // "😋 Pet đã được cho ăn!"
```

### 5. Thăm nhà bạn

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => HouseScreen(ownerUid: friendUid),
  ),
);
```

---

## 🎨 Design Patterns

### Grid System
- **8 columns × 6 rows** = 48 cells
- **Cell size**: `screenWidth / 8`
- **Isometric feel**: Checkerboard floor pattern

### Color Schemes
- **Warm**: Tường gỗ + sàn gỗ + đèn vàng
- **Cool**: Tường xanh + sàn đá + đèn trắng
- **Cozy**: Tường hồng + thảm + đèn dây
- **Nature**: Tường cỏ + sàn cỏ + cây cảnh

### Animation
- **Pet bounce**: 800ms repeat
- **Character move**: 300ms easeOut
- **Item placement**: 200ms scale
- **Edit mode**: Border highlight

---

## 🐛 Known Issues

1. **Collision detection**: Chưa có, vật phẩm có thể chồng lên nhau
2. **Z-index**: Chưa sort theo gridY (vật phẩm phía sau nên render trước)
3. **Multi-cell items**: Chưa hỗ trợ vật phẩm chiếm nhiều ô
4. **Pet AI**: Pet chưa tự di chuyển, chỉ đứng yên
5. **Visitors interaction**: Chưa có chat/tương tác với khách

---

## 🔮 Future Enhancements

- [ ] **Collision detection** cho vật phẩm
- [ ] **Z-index sorting** theo gridY
- [ ] **Multi-cell items** (giường 2x1, sofa 3x1...)
- [ ] **Pet AI** tự di chuyển ngẫu nhiên
- [ ] **Pet mini-games** (fetch, hide & seek...)
- [ ] **Seasons** (Xuân/Hạ/Thu/Đông) với decor đặc biệt
- [ ] **Weather effects** (mưa, tuyết, nắng)
- [ ] **Day/night cycle** (sáng/tối)
- [ ] **Room expansion** (mở rộng phòng)
- [ ] **Multiple rooms** (phòng ngủ, phòng khách, bếp...)
- [ ] **Garden** (trồng cây, hái quả)
- [ ] **Fishing pond** (câu cá mini-game)
- [ ] **Guest book** (khách để lại lời nhắn)
- [ ] **Photo mode** (chụp ảnh phòng để share)

---

## 📝 Notes

- **Grid coordinates**: (0,0) = top-left, (7,5) = bottom-right
- **Rotation**: 0° = facing right, 90° = facing down, 180° = facing left, 270° = facing up
- **Pet decay**: Gọi `decayPetStats()` khi mở app
- **Visitors**: Tối đa 20 visitors gần nhất (có thể limit)
- **Default items**: Tường trắng, sàn xanh, giường cơ bản (miễn phí, không thể xoá)

---

**Status**: ✅ **HOÀN THÀNH**

**Features**:
- ✅ Trang trí phòng với 34 vật phẩm
- ✅ Nuôi pet với 4 loại
- ✅ Mua đồ bằng Gold Coin
- ✅ Thăm nhà bạn bè
- ✅ Character di chuyển
- ✅ Edit mode đầy đủ

**Ready for**: 🚀 Testing & Deployment

---

Made with 💜 by Vocabo Team
