/**
 * App.jsx — Root component
 * - Fetch config từ backend khi khởi động
 * - Init Firebase với config đó
 * - Setup routing
 */
import { useEffect, useState } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { fetchConfig } from "./lib/api";
import { initFirebase } from "./lib/firebase";
import { useAppStore } from "./store/appStore";

import Toast          from "./components/Toast";
import LoadingOverlay from "./components/LoadingOverlay";
import Layout         from "./components/Layout";

import LoginPage          from "./pages/LoginPage";
import DashboardPage      from "./pages/DashboardPage";
import SearchPage         from "./pages/SearchPage";
import PlaceholderPage    from "./pages/PlaceholderPage";
import FlashcardPage      from "./pages/FlashcardPage";
import ReviewPage         from "./pages/ReviewPage";
import TestPage           from "./pages/TestPage";
import GrammarPage        from "./pages/GrammarPage";
import CalendarPage       from "./pages/CalendarPage";
import ProfilePage        from "./pages/ProfilePage";
import AdminPage          from "./pages/AdminPage";
import WordStoryPage      from "./pages/WordStoryPage";
import DailyChallengePage from "./pages/DailyChallengePage";
import VocabMapPage       from "./pages/VocabMapPage";
import AIConversationPage from "./pages/AIConversationPage";
import ShadowingPage      from "./pages/ShadowingPage";
import SmartSrsPage       from "./pages/SmartSrsPage";
import GamesPage          from "./pages/GamesPage";
import HousePage          from "./pages/HousePage";
import FarmPage           from "./pages/FarmPage";
import FriendsPage        from "./pages/FriendsPage";
import ChatPage           from "./pages/ChatPage";

export default function App() {
  const { setConfig, configLoaded } = useAppStore();
  const [initError, setInitError] = useState(null);

  // ── Fetch config từ backend, init Firebase ─────────────────────────────────
  useEffect(() => {
    fetchConfig()
      .then((config) => {
        initFirebase(config.firebase);
        setConfig(config);
      })
      .catch((err) => {
        console.error("Failed to load config:", err);
        setInitError("Không thể kết nối đến server. Vui lòng thử lại.");
      });
  }, []);

  if (initError) {
    return (
      <div className="min-h-screen bg-[#f0f2f8] flex items-center justify-center p-6">
        <div className="bg-white rounded-2xl shadow-card p-8 text-center max-w-sm">
          <div className="text-5xl mb-4">⚠️</div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">Lỗi kết nối</h2>
          <p className="text-gray-500 text-sm mb-5">{initError}</p>
          <button
            onClick={() => window.location.reload()}
            className="px-5 py-2.5 rounded-xl bg-gradient-primary text-white font-semibold text-sm"
          >
            Thử lại
          </button>
        </div>
      </div>
    );
  }

  if (!configLoaded) {
    return (
      <div className="min-h-screen bg-[#f0f2f8] flex items-center justify-center">
        <div className="text-center">
          <div className="w-14 h-14 border-4 border-primary-light border-t-primary rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500 text-sm font-medium">Đang khởi động VOCABO...</p>
        </div>
      </div>
    );
  }

  return (
    <BrowserRouter>
      <Toast />
      <LoadingOverlay />

      <Routes>
        {/* Auth */}
        <Route path="/"           element={<LoginPage />} />
        <Route path="/setup-admin" element={<PlaceholderPage title="Setup Admin" emoji="🛡️" />} />

        {/* Protected — wrapped in Layout */}
        <Route path="/dashboard" element={<Layout><DashboardPage /></Layout>} />
        <Route path="/search"    element={<Layout><SearchPage /></Layout>} />

        {/* Implemented pages */}
        <Route path="/flashcard"      element={<Layout><FlashcardPage /></Layout>} />
        <Route path="/review"         element={<Layout><ReviewPage /></Layout>} />
        <Route path="/test"           element={<Layout><TestPage /></Layout>} />
        <Route path="/grammar"        element={<Layout><GrammarPage /></Layout>} />
        <Route path="/calendar"       element={<Layout><CalendarPage /></Layout>} />
        <Route path="/profile"        element={<Layout><ProfilePage /></Layout>} />
        <Route path="/admin"          element={<Layout><AdminPage /></Layout>} />

        {/* ── Tính năng mới ── */}
        <Route path="/word-story"      element={<Layout><WordStoryPage /></Layout>} />
        <Route path="/daily-challenge" element={<Layout><DailyChallengePage /></Layout>} />
        <Route path="/vocab-map"       element={<Layout><VocabMapPage /></Layout>} />
        <Route path="/ai-conversation" element={<Layout><AIConversationPage /></Layout>} />
        <Route path="/shadowing"       element={<Layout><ShadowingPage /></Layout>} />
        <Route path="/smart-srs"       element={<Layout><SmartSrsPage /></Layout>} />

        {/* ── Gamification & Social ── */}
        <Route path="/games"   element={<Layout><GamesPage /></Layout>} />
        <Route path="/house"   element={<Layout><HousePage /></Layout>} />
        <Route path="/farm"    element={<Layout><FarmPage /></Layout>} />
        <Route path="/friends" element={<Layout><FriendsPage /></Layout>} />
        <Route path="/chat"    element={<Layout><ChatPage /></Layout>} />

        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
