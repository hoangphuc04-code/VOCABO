# VOCABO — Kiến trúc Frontend / Backend

## Tổng quan

```
vocabo/
├── frontend/          ← React + Vite (SPA)
│   ├── src/
│   │   ├── components/    ← Layout, Toast, LoadingOverlay, MeowChat
│   │   ├── hooks/         ← useAuth
│   │   ├── lib/           ← firebase.js, api.js (axios)
│   │   ├── pages/         ← LoginPage, DashboardPage, SearchPage, ...
│   │   ├── store/         ← Zustand global state
│   │   ├── App.jsx
│   │   └── main.jsx
│   ├── .env.example
│   └── vite.config.js
│
├── backend/           ← Python Flask REST API
│   ├── api/
│   │   └── routes/
│   │       ├── config_routes.py      ← GET /api/config
│   │       ├── proxy_routes.py       ← GET /api/dictionary, /api/translate
│   │       ├── ai_routes.py          ← POST /api/ai/chat, /api/ai/study-plan
│   │       └── dictionary_routes.py  ← GET /api/word/<word>, POST /api/word-batch
│   ├── app.py
│   ├── config.py
│   └── requirements.txt
│
├── mobile/            ← Flutter app (Android/iOS/macOS)
│   └── lib/
│
├── functions/         ← Firebase Cloud Functions (Node.js)
│   └── index.js
│
└── webapp/            ← Legacy Python webapp (sẽ deprecated)
    └── ...
```

## Luồng dữ liệu

```
React Frontend
    │
    ├── GET /api/config          → Lấy Firebase config, admin emails, cloudinary config
    │       ↓
    │   initFirebase(config)     → Khởi tạo Firebase SDK
    │
    ├── Firebase Auth (client)   → Đăng nhập trực tiếp với Firebase
    │
    ├── Firestore (client)       → Đọc/ghi dữ liệu trực tiếp
    │
    └── Backend API calls:
        ├── GET  /api/word/<word>     → Tra từ (Oxford + MyMemory)
        ├── POST /api/word-batch      → Tra nhiều từ (seeding flashcard)
        ├── GET  /api/translate       → Dịch text
        ├── POST /api/ai/chat         → Meow AI Chat (Groq)
        └── POST /api/ai/study-plan   → Tạo kế hoạch học tập
```

## Chạy Development

### Backend
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env   # điền API keys
python app.py
# → http://localhost:8000
```

### Frontend
```bash
cd frontend
npm install
cp .env.example .env.local
npm run dev
# → http://localhost:5173
```

## API Endpoints

| Method | Endpoint              | Mô tả                          |
|--------|-----------------------|--------------------------------|
| GET    | /health               | Health check                   |
| GET    | /api/config           | App config (Firebase, etc.)    |
| GET    | /api/word/\<word\>    | Tra từ đầy đủ                  |
| POST   | /api/word-batch       | Tra nhiều từ                   |
| GET    | /api/translate        | Dịch text                      |
| GET    | /api/dictionary/\<w\> | Proxy Oxford Dictionary        |
| POST   | /api/ai/chat          | Meow AI Chat                   |
| POST   | /api/ai/study-plan    | Tạo kế hoạch học tập           |

## Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| Frontend  | React 18, Vite, Tailwind CSS, Zustand, React Router, Axios |
| Backend   | Python Flask, Flask-CORS            |
| Database  | Firebase Firestore (client SDK)     |
| Auth      | Firebase Authentication             |
| AI        | Groq API (llama-3.3-70b)            |
| Storage   | Cloudinary (avatar upload)          |
| Mobile    | Flutter (Android/iOS/macOS)         |
