/**
 * api.js — Axios instance để gọi Backend REST API
 */
import axios from "axios";

const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:8000/api";

const api = axios.create({
  baseURL: API_BASE,
  timeout: 30000,
  headers: { "Content-Type": "application/json" },
});

// ── Request interceptor: attach Firebase ID token ─────────────────────────────
api.interceptors.request.use(async (config) => {
  try {
    const { getFirebaseAuth } = await import("./firebase");
    const auth = getFirebaseAuth();
    if (auth?.currentUser) {
      const token = await auth.currentUser.getIdToken();
      config.headers.Authorization = `Bearer ${token}`;
    }
  } catch (_) {}
  return config;
});

// ── Response interceptor: handle errors ───────────────────────────────────────
api.interceptors.response.use(
  (res) => res,
  (err) => {
    const msg = err.response?.data?.error || err.message || "Network error";
    return Promise.reject(new Error(msg));
  }
);

// ── API methods ────────────────────────────────────────────────────────────────

/** Lấy app config từ backend */
export const fetchConfig = () => api.get("/config").then((r) => r.data);

/** Tra từ điển */
export const lookupWord  = (word) => api.get(`/word/${encodeURIComponent(word)}`).then((r) => r.data);

/** Tra nhiều từ cùng lúc */
export const lookupBatch = (words) => api.post("/word-batch", { words }).then((r) => r.data);

/** Dịch text */
export const translateText = (q, langpair = "en|vi") =>
  api.get("/translate", { params: { q, langpair } }).then((r) => r.data);

/** Meow AI Chat (text + image) */
export const meowChat = (messages, options = {}) =>
  api.post("/ai/chat", { messages, ...options }).then((r) => r.data);

/** Tạo kế hoạch học tập → calendar events */
export const generateStudyPlan = (params) =>
  api.post("/ai/study-plan", params).then((r) => r.data);

/** Tạo tin nhắn động viên */
export const generateMotivation = (userData, trigger) =>
  api.post("/ai/motivate", { userData, trigger }).then((r) => r.data);

/** Phát hiện conflict lịch */
export const detectConflicts = (newEvent, existingEvents) =>
  api.post("/ai/detect-conflicts", { newEvent, existingEvents }).then((r) => r.data);

/** Phân tích ảnh */
export const analyzeImage = (image_base64, context = "general") =>
  api.post("/ai/analyze-image", { image_base64, context }).then((r) => r.data);

export default api;
