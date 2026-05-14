/**
 * Layout.jsx — Main app layout: Navbar + Sidebar + Content
 */
import { useState } from "react";
import { Link, useLocation, Navigate } from "react-router-dom";
import { signOut } from "firebase/auth";
import { getFirebaseAuth, getFirebaseDb } from "../lib/firebase";
import { useAuth } from "../hooks/useAuth";
import { collection, query, where, onSnapshot } from "firebase/firestore";
import { useEffect } from "react";
import MeowChat from "./MeowChat";

const NAV_LINKS = [
  { to: "/dashboard", emoji: "🏠", label: "Trang chủ" },
  { to: "/flashcard",  emoji: "📚", label: "Học" },
  { to: "/games",      emoji: "🎮", label: "Games" },
  { to: "/house",      emoji: "🏡", label: "Nhà" },
  { to: "/chat",       emoji: "💬", label: "Chat" },
];

const SIDEBAR_SECTIONS = [
  {
    title: "Học tập",
    links: [
      { to: "/dashboard",  emoji: "🏠", label: "Trang chủ" },
      { to: "/flashcard",  emoji: "📚", label: "Học từ vựng" },
      { to: "/review",     emoji: "🔁", label: "Ôn tập" },
      { to: "/smart-srs",  emoji: "🧠", label: "Smart SRS" },
      { to: "/test",       emoji: "📝", label: "Kiểm tra" },
      { to: "/grammar",    emoji: "📖", label: "Ngữ pháp" },
      { to: "/calendar",   emoji: "📅", label: "Lịch học" },
      { to: "/search",     emoji: "🔍", label: "Tra từ" },
    ],
  },
  {
    title: "🚀 Tính năng mới",
    links: [
      { to: "/word-story",      emoji: "📖", label: "Word Story" },
      { to: "/daily-challenge", emoji: "🏆", label: "Daily Challenge" },
      { to: "/vocab-map",       emoji: "🗺️", label: "Vocab Map" },
      { to: "/shadowing",       emoji: "🎙️", label: "Shadowing" },
      { to: "/ai-conversation", emoji: "🤖", label: "AI Conversation" },
    ],
  },
  {
    title: "Giải trí",
    links: [
      { to: "/games",  emoji: "🎮", label: "Mini Games" },
      { to: "/house",  emoji: "🏡", label: "Mini House" },
      { to: "/farm",   emoji: "🌿", label: "Nông trại" },
    ],
  },
  {
    title: "Xã hội",
    links: [
      { to: "/friends", emoji: "👥", label: "Bạn bè" },
      { to: "/chat",    emoji: "💬", label: "Tin nhắn" },
    ],
  },
  {
    title: "Tài khoản",
    links: [
      { to: "/profile", emoji: "👤", label: "Hồ sơ" },
    ],
  },
];

export default function Layout({ children }) {
  const { user, userData, authLoading } = useAuth();
  const location = useLocation();
  const [chatUnread, setChatUnread] = useState(0);
  const [friendReqs, setFriendReqs] = useState(0);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;

    // Listen chat unread
    const convQ = query(collection(db, "conversations"), where("participants", "array-contains", user.uid));
    const unsubConv = onSnapshot(convQ, (snap) => {
      let total = 0;
      snap.forEach((d) => {
        const unread = d.data()?.unread?.[user.uid] || 0;
        total += unread;
      });
      setChatUnread(total);
    });

    // Listen friend requests
    const reqQ = query(
      collection(db, "friend_requests"),
      where("toUid", "==", user.uid),
      where("status", "==", "pending")
    );
    const unsubReq = onSnapshot(reqQ, (snap) => setFriendReqs(snap.size));

    return () => { unsubConv(); unsubReq(); };
  }, [user]);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#f0f2f8]">
        <div className="w-12 h-12 border-4 border-primary-light border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) return <Navigate to="/" replace />;

  const name     = userData?.displayName || user.displayName || user.email || "User";
  const photo    = userData?.photoURL || user.photoURL || "";
  const initials = name.charAt(0).toUpperCase();
  const coins    = userData?.coins || 0;
  const diamonds = userData?.diamonds || 0;
  const hearts   = userData?.hearts ?? 5;

  const handleLogout = async () => {
    await signOut(getFirebaseAuth());
  };

  const totalBadge = chatUnread + friendReqs;

  return (
    <div className="min-h-screen bg-[#f0f2f8]">
      {/* ── Navbar ── */}
      <nav className="bg-white h-16 flex items-center px-4 md:px-6 shadow-sm sticky top-0 z-50 gap-3">
        {/* Mobile menu toggle */}
        <button
          className="md:hidden p-2 rounded-xl hover:bg-gray-100"
          onClick={() => setSidebarOpen(!sidebarOpen)}
        >
          <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>

        <Link to="/dashboard" className="flex items-center gap-2 font-extrabold text-xl no-underline flex-shrink-0">
          <div className="w-9 h-9 rounded-xl bg-gradient-primary flex items-center justify-center text-white text-lg">
            📖
          </div>
          <span className="gradient-text hidden sm:block">VOCABO</span>
        </Link>

        {/* Desktop nav links */}
        <div className="hidden md:flex items-center gap-1 ml-4">
          {NAV_LINKS.map(({ to, emoji, label }) => {
            const badge = (to === "/chat" || to === "/friends") ? totalBadge : 0;
            return (
              <Link
                key={to}
                to={to}
                className={`relative flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm font-semibold transition-all
                  ${location.pathname.startsWith(to) && to !== "/dashboard"
                    ? "bg-primary-light text-primary"
                    : location.pathname === to
                    ? "bg-primary-light text-primary"
                    : "text-gray-500 hover:bg-primary-light hover:text-primary"
                  }`}
              >
                <span>{emoji}</span>
                <span>{label}</span>
                {badge > 0 && (
                  <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                    {badge > 9 ? "9+" : badge}
                  </span>
                )}
              </Link>
            );
          })}
        </div>

        <div className="ml-auto flex items-center gap-2">
          {/* Currency pills */}
          <div className="hidden sm:flex items-center gap-1.5">
            <span className="flex items-center gap-1 bg-yellow-50 border border-yellow-200 px-2.5 py-1 rounded-full text-xs font-bold text-yellow-700">
              🪙 {coins}
            </span>
            <span className="flex items-center gap-1 bg-purple-50 border border-purple-200 px-2.5 py-1 rounded-full text-xs font-bold text-purple-700">
              💎 {diamonds}
            </span>
            <span className="flex items-center gap-1 bg-red-50 border border-red-200 px-2.5 py-1 rounded-full text-xs font-bold text-red-600">
              {"❤️".repeat(Math.min(hearts, 5))}
            </span>
          </div>

          {/* User avatar */}
          <Link to="/profile" className="flex items-center gap-2 hover:opacity-80 transition-opacity ml-1">
            <div
              className="w-9 h-9 rounded-full overflow-hidden flex items-center justify-center font-bold text-white text-sm flex-shrink-0"
              style={{ background: "linear-gradient(135deg,#667eea,#764ba2)" }}
            >
              {photo ? (
                <img src={photo} className="w-full h-full object-cover" alt="" />
              ) : (
                initials
              )}
            </div>
            <span className="text-sm font-semibold text-gray-700 hidden lg:block">
              {name.split(" ").pop()}
            </span>
          </Link>

          {/* Logout */}
          <button
            onClick={handleLogout}
            className="hidden md:flex items-center gap-1 px-3 py-2 rounded-xl text-sm text-gray-500 hover:bg-red-50 hover:text-red-500 transition-all"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </button>
        </div>
      </nav>

      {/* ── Body ── */}
      <div className="flex min-h-[calc(100vh-64px)]">
        {/* Mobile sidebar overlay */}
        {sidebarOpen && (
          <div
            className="fixed inset-0 bg-black/40 z-40 md:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}

        {/* Sidebar */}
        <aside className={`
          fixed md:sticky top-16 h-[calc(100vh-64px)] z-40
          w-60 bg-white border-r border-gray-100 p-4 flex-col gap-1 overflow-y-auto
          transition-transform duration-300
          ${sidebarOpen ? "translate-x-0 flex" : "-translate-x-full md:translate-x-0 hidden md:flex"}
        `}>
          {SIDEBAR_SECTIONS.map((section) => (
            <div key={section.title} className="mb-2">
              <p className="text-xs font-bold text-gray-400 uppercase tracking-wider px-3 mb-1.5">
                {section.title}
              </p>
              {section.links.map((link) => {
                const active = location.pathname === link.to;
                const badge =
                  link.to === "/chat" ? chatUnread :
                  link.to === "/friends" ? friendReqs : 0;
                return (
                  <Link
                    key={link.to}
                    to={link.to}
                    onClick={() => setSidebarOpen(false)}
                    className={`relative flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm font-medium transition-all
                      ${active
                        ? "bg-primary-light text-primary font-bold"
                        : "text-gray-500 hover:bg-primary-light hover:text-primary"
                      }`}
                  >
                    <span className="w-5 text-center">{link.emoji}</span>
                    {link.label}
                    {badge > 0 && (
                      <span className="ml-auto w-5 h-5 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                        {badge > 9 ? "9+" : badge}
                      </span>
                    )}
                  </Link>
                );
              })}
              <div className="border-t border-gray-100 mt-2" />
            </div>
          ))}

          {/* Logout button */}
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm font-medium text-red-400 hover:bg-red-50 hover:text-red-500 transition-all mt-auto"
          >
            <span className="w-5 text-center">🚪</span>
            Đăng xuất
          </button>
        </aside>

        {/* Main content */}
        <main className="flex-1 p-4 md:p-6 overflow-y-auto min-w-0">{children}</main>
      </div>

      {/* Meow AI Chat */}
      <MeowChat />
    </div>
  );
}
