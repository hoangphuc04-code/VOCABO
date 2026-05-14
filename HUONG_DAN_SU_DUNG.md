# 🐱 Hướng dẫn sử dụng Meow AI

## 🎯 Tính năng mới

### 1. Thiết lập mục tiêu học tập

**Bước 1:** Mở app và nhấn vào icon **cờ** (🚩) trên thanh công cụ của Meow AI

**Bước 2:** Trả lời 5 câu hỏi:
- **Trình độ hiện tại**: Chọn từ A1 đến C2
- **Mục tiêu**: Chọn trình độ muốn đạt và ngày mục tiêu
- **Thời gian học**: Chọn số phút học mỗi ngày (10-60 phút)
- **Khung giờ rảnh**: Chọn buổi sáng/chiều/tối/đêm (có thể chọn nhiều)
- **Phong cách động viên**: 
  - 😸 **Vui vẻ**: Tin nhắn dễ thương, hài hước
  - 🌸 **Nhẹ nhàng**: Nhắc nhở ân cần, không áp lực
  - 💪 **Nghiêm túc**: Thúc giục mạnh mẽ để đạt mục tiêu

**Bước 3:** Nhấn **Hoàn thành** để lưu

---

### 2. Chat với Meow AI

#### 📝 Gửi tin nhắn văn bản

1. Nhấn vào **bubble Meow** (😺) ở góc màn hình
2. Gõ câu hỏi hoặc yêu cầu, ví dụ:
   - "Lập kế hoạch học IELTS 6 tháng"
   - "Tạo lịch ôn tập từ vựng hàng ngày"
   - "Gợi ý cách học từ vựng hiệu quả"
3. Nhấn nút **gửi** (✈️)

#### 📷 Gửi hình ảnh

1. Nhấn vào icon **hình ảnh** (🖼️) bên trái ô nhập tin
2. Chọn:
   - **Thư viện**: Chọn ảnh có sẵn
   - **Camera**: Chụp ảnh mới
3. Gõ câu hỏi (hoặc để trống), ví dụ:
   - "Đọc lịch trong ảnh này"
   - "Thêm các sự kiện trong ảnh vào lịch"
4. Nhấn **gửi**

**Meow AI sẽ:**
- Đọc và phân tích nội dung ảnh
- Tự động phát hiện lịch/sự kiện
- Đề xuất thêm vào calendar

---

### 3. Xử lý xung đột lịch

Khi thêm sự kiện mới trùng với sự kiện cũ, Meow sẽ hiển thị dialog với **3 lựa chọn**:

#### Lựa chọn 1: Ưu tiên sự kiện MỚI
- Sự kiện mới được giữ nguyên
- Sự kiện cũ bị lùi 1 tiếng

#### Lựa chọn 2: Ưu tiên sự kiện CŨ
- Sự kiện cũ được giữ nguyên
- Sự kiện mới bị lùi 1 tiếng

#### Lựa chọn 3: Xóa sự kiện cũ
- Sự kiện cũ bị xóa hoàn toàn
- Sự kiện mới được thêm vào

**Chọn lựa chọn phù hợp và nhấn vào nút tương ứng**

---

### 4. Kế hoạch học tập tự động

#### Cách tạo kế hoạch

1. Chat với Meow: "Tạo kế hoạch học IELTS 6 tháng"
2. Meow sẽ phân tích mục tiêu của bạn và tạo:
   - **Các mốc thời gian** (milestones) cụ thể
   - **Danh sách công việc** cho mỗi mốc
   - **Sự kiện lịch** tự động

3. Xem trước kế hoạch trong bottom sheet
4. Nhấn **Lưu kế hoạch** để:
   - Lưu kế hoạch vào Firestore
   - Thêm tất cả sự kiện vào calendar

#### Xem kế hoạch đã lưu

1. Vào **Calendar** (📅)
2. Các sự kiện từ AI có icon 😺
3. Nhấn vào sự kiện để xem chi tiết

---

### 5. Tin nhắn động viên tự động

Meow sẽ tự động gửi tin nhắn động viên:

#### Khi nào nhận được?
- **Mỗi 4-6 giờ** nếu chưa học
- **Khi streak sắp bị gãy** (chưa học hôm nay)
- **Nhắc nhở mục tiêu** định kỳ

#### Xem thông báo
- **Badge đỏ** trên bubble Meow (😺) → Có thông báo mới
- Nhấn vào bubble để xem
- Thông báo tự động đánh dấu đã đọc

#### Tùy chỉnh phong cách
Vào **Mục tiêu học tập** để thay đổi phong cách động viên:
- 😸 Vui vẻ: "Meow~ Hôm nay bạn đã học chưa?"
- 🌸 Nhẹ nhàng: "Chào bạn, hôm nay bạn có muốn học một chút không?"
- 💪 Nghiêm túc: "Bạn chưa học hôm nay! Đừng để streak bị gãy!"

---

## 💡 Mẹo sử dụng

### Chat hiệu quả với Meow

✅ **NÊN:**
- Hỏi cụ thể: "Lập kế hoạch học IELTS 7.0 trong 6 tháng"
- Gửi ảnh lịch viết tay hoặc chụp màn hình
- Yêu cầu thêm lịch: "Thêm lịch học từ vựng mỗi sáng 7h"

❌ **KHÔNG NÊN:**
- Hỏi quá chung chung: "Giúp tôi học tiếng Anh"
- Gửi ảnh mờ hoặc chữ viết khó đọc
- Yêu cầu quá nhiều việc trong 1 tin nhắn

### Quản lý lịch

- **Xem lịch**: Nhấn icon 📅 trên thanh công cụ
- **Xóa lịch sử chat**: Nhấn icon 🗑️
- **Di chuyển bubble**: Giữ và kéo bubble Meow đến vị trí mong muốn

### Tối ưu học tập

1. **Thiết lập mục tiêu rõ ràng** ngay từ đầu
2. **Chọn khung giờ rảnh chính xác** để nhận nhắc nhở đúng lúc
3. **Kiểm tra lịch hàng ngày** để không bỏ lỡ buổi học
4. **Tương tác với Meow thường xuyên** để nhận gợi ý cá nhân hóa

---

## 🐛 Xử lý sự cố

### Meow không trả lời
- Kiểm tra kết nối internet
- Thử gửi lại tin nhắn
- Khởi động lại app

### Không đọc được ảnh
- Đảm bảo ảnh rõ nét, không bị mờ
- Chụp lại với ánh sáng tốt hơn
- Thử gõ thông tin thủ công

### Không nhận được thông báo động viên
- Kiểm tra đã thiết lập mục tiêu chưa
- Vào **Settings** → Bật thông báo
- Đảm bảo app không bị force stop

### Xung đột lịch không hiển thị
- Kiểm tra múi giờ thiết bị
- Đảm bảo đã đăng nhập Firebase
- Thử xóa cache và đăng nhập lại

---

## 📞 Hỗ trợ

Nếu gặp vấn đề, hãy:
1. Đọc lại hướng dẫn này
2. Kiểm tra file `MEOW_AI_FEATURES.md` (dành cho dev)
3. Liên hệ team phát triển

---

**Chúc bạn học tiếng Anh vui vẻ cùng Meow! 😺💜**
