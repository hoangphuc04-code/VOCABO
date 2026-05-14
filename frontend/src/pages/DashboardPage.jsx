/**
 * DashboardPage.jsx — Trang chủ
 */
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { collection, query, where, getDocs, orderBy, limit } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const LEVELS      = ["A1", "A2", "B1", "B2", "C1", "C2"];
const LEVEL_COLORS = { A1:"#3b82f6", A2:"#10b981", B1:"#f59e0b", B2:"#8b5cf6", C1:"#ef4444", C2:"#14b8a6" };
const DAYS        = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
const MENU_ITEMS  = [
  { to: "/flashcard", emoji: "📚", label: "Học từ vựng", bg: "#eef0ff" },
  { to: "/review",    emoji: "🔁", label: "Ôn tập",      bg: "#f0fdf4" },
  { to: "/test",      emoji: "📝", label: "Kiểm tra",    bg: "#fff7ed" },
  { to: "/grammar",   emoji: "📖", label: "Ngữ pháp",    bg: "#fdf4ff" },
];

const NEW_FEATURES = [
  { to: "/word-story",      emoji: "📖", label: "Word Story",      bg: "#eef0ff", desc: "Học qua câu chuyện AI" },
  { to: "/daily-challenge", emoji: "🏆", label: "Daily Challenge", bg: "#fff7ed", desc: "Thử thách hàng ngày" },
  { to: "/vocab-map",       emoji: "🗺️", label: "Vocab Map",       bg: "#f0fdf4", desc: "Bản đồ từ vựng" },
  { to: "/shadowing",       emoji: "🎙️", label: "Shadowing",       bg: "#fdf4ff", desc: "Luyện phát âm câu" },
  { to: "/ai-conversation", emoji: "🤖", label: "AI Chat",         bg: "#fef3c7", desc: "Hội thoại với AI" },
  { to: "/smart-srs",       emoji: "🧠", label: "Smart SRS",       bg: "#ede9fe", desc: "Ôn tập thông minh" },
];
const NOTIF_TYPES = {
  info:    ["📢", "bg-blue-50"],
  success: ["🎉", "bg-green-50"],
  warning: ["⚠️", "bg-orange-50"],
  error:   ["🚨", "bg-red-50"],
};

const GAMIFICATION = [
  { to: "/games",   emoji: "🎮", label: "Mini Games",  bg: "#f3e8ff", desc: "Speed Quiz & mini games" },
  { to: "/house",   emoji: "🏡", label: "Mini House",  bg: "#fef9c3", desc: "Trang trí nhà & thú cưng" },
  { to: "/farm",    emoji: "🌿", label: "Nông trại",   bg: "#dcfce7", desc: "Trồng cây, nuôi động vật" },
  { to: "/friends", emoji: "👥", label: "Bạn bè",      bg: "#ede9fe", desc: "Kết bạn & cạnh tranh" },
  { to: "/chat",    emoji: "💬", label: "Tin nhắn",    bg: "#e0f2fe", desc: "Chat với bạn bè" },
];

export default function DashboardPage() {
  const { user, userData } = useAppStore((s) => ({ user: s.user, userData: s.userData }));
  const [weekData, setWeekData] = useState(new Array(7).fill(0));
  const [notifs,   setNotifs]   = useState([]);
  const [gameStats, setGameStats] = useState({ coins: 0, friends: 0, challengeScore: 0 });

  const name    = userData?.displayName || user?.displayName || "Bạn";
  const photo   = userData?.photoURL || user?.photoURL || "";
  const level   = userData?.level || "A1";
  const goal    = userData?.dailyGoal || 10;
  const learned = userData?.wordsLearned || 0;
  const todayW  = learned % goal;
  const goalPct = Math.min(100, Math.round((todayW / goal) * 100));

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();

    // Weekly chart
    getDocs(query(collection(db, "study_sessions"), where("uid", "==", user.uid)))
      .then((snap) => {
        const data = new Array(7).fill(0);
        snap.forEach((d) => {
          const date = d.data().date?.toDate?.();
          if (date) data[date.getDay() === 0 ? 6 : date.getDay() - 1] += d.data().wordsLearned || 0;
        });
        setWeekData(data);
      })
      .catch(() => {});

    // Notifications
    getDocs(query(collection(db, "notifications"), orderBy("createdAt", "desc"), limit(5)))
      .then((snap) => setNotifs(snap.docs.map((d) => ({ id: d.id, ...d.data() }))))
      .catch(() => {});

    // Game stats: friends count + today challenge score
    Promise.all([
      getDocs(query(collection(db, "friendships"), where("uids", "array-contains", user.uid))),
      getDocs(query(
        collection(db, "daily_challenge_scores"),
        where("uid", "==", user.uid),
        where("date", "==", new Date().toISOString().slice(0, 10)),
        limit(1)
      )),
    ]).then(([friendsSnap, challengeSnap]) => {
      const score = challengeSnap.docs[0]?.data()?.score || 0;
      setGameStats({
        coins: userData?.coins || 0,
        friends: friendsSnap.size,
        challengeScore: score,
      });
    }).catch(() => {});
  }, [user, userData]);

  const maxWeek = Math.max(...weekData, 1);

  return (
    <div>
      {/* Hero */}
      <div className="bg-gradient-primary rounded-2xl p-7 text-white mb-6 flex items-center justify-between">
        <div>
          <p className="text-sm opacity-80 mb-1">Chào mừng trở lại 👋</p>
          <h2 className="text-2xl font-black">{name}</h2>
          <p className="text-sm opacity-75 mt-1">Cấp độ {level} • Mục tiêu {goal} từ/ngày</p>
        </div>
        <div className="w-16 h-16 rounded-full border-4 border-white/30 bg-white/20 flex items-center justify-center text-3xl font-black overflow-hidden flex-shrink-0">
          {photo ? <img src={photo} className="w-full h-full object-cover" alt="" /> : name.charAt(0).toUpperCase()}
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {[
          { icon: "📚", value: (learned).toLocaleString(), label: "Từ đã học",   bg: "bg-primary-light" },
          { icon: "🔥", value: userData?.streak || 0,      label: "Streak ngày", bg: "bg-orange-50" },
          { icon: "📊", value: Math.round((userData?.progress || 0) * 100) + "%", label: "Tiến độ", bg: "bg-green-50" },
          { icon: "🎯", value: (userData?.lastTestScore || 0) + "%", label: "Điểm test", bg: "bg-purple-50" },
        ].map(({ icon, value, label, bg }) => (
          <div key={label} className="bg-white rounded-2xl shadow-card p-5 flex items-center gap-4">
            <div className={`w-12 h-12 rounded-2xl ${bg} flex items-center justify-center text-2xl flex-shrink-0`}>{icon}</div>
            <div>
              <div className="text-2xl font-black text-gray-800">{value}</div>
              <div className="text-xs text-gray-500 font-medium">{label}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Quick Menu */}
      <h3 className="text-base font-bold text-gray-700 mb-3">⚡ Chức năng chính</h3>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {MENU_ITEMS.map(({ to, emoji, label, bg }) => (
          <Link key={to} to={to}
            className="bg-white rounded-2xl shadow-card p-5 text-center hover:-translate-y-1 transition-transform no-underline text-gray-800">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-3xl mx-auto mb-3" style={{ background: bg }}>
              {emoji}
            </div>
            <div className="text-sm font-semibold">{label}</div>
          </Link>
        ))}
      </div>

      {/* New Features */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl p-5 mb-6">
        <div className="flex items-center gap-2 mb-4">
          <span className="text-xl">🚀</span>
          <h3 className="text-base font-bold text-white">Tính năng mới nổi bật</h3>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          {NEW_FEATURES.map(({ to, emoji, label, desc }) => (
            <Link key={to} to={to}
              className="bg-white/15 hover:bg-white/25 rounded-xl p-3 text-white no-underline transition-all hover:-translate-y-0.5">
              <div className="text-2xl mb-1">{emoji}</div>
              <div className="text-sm font-bold">{label}</div>
              <div className="text-xs text-indigo-200 mt-0.5">{desc}</div>
            </Link>
          ))}
        </div>
      </div>

      {/* Gamification */}
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-3">
          <span className="text-xl">🎮</span>
          <h3 className="text-base font-bold text-gray-700">Giải trí & Xã hội</h3>
          <div className="ml-auto flex items-center gap-3 text-sm">
            <span className="flex items-center gap-1 bg-yellow-50 border border-yellow-200 px-2.5 py-1 rounded-full font-bold text-yellow-700">
              🪙 {userData?.coins || 0}
            </span>
            <span className="flex items-center gap-1 bg-purple-50 border border-purple-200 px-2.5 py-1 rounded-full font-bold text-purple-700">
              💎 {userData?.diamonds || 0}
            </span>
            <span className="flex items-center gap-1 bg-red-50 border border-red-200 px-2.5 py-1 rounded-full font-bold text-red-600">
              ❤️ {userData?.hearts ?? 5}
            </span>
          </div>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          {GAMIFICATION.map(({ to, emoji, label, bg, desc }) => (
            <Link key={to} to={to}
              className="bg-white rounded-2xl shadow-card p-4 text-center hover:-translate-y-1 transition-transform no-underline text-gray-800 group">
              <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-2xl mx-auto mb-2 group-hover:scale-110 transition-transform"
                style={{ background: bg }}>
                {emoji}
              </div>
              <div className="text-sm font-bold">{label}</div>
              <div className="text-xs text-gray-400 mt-0.5">{desc}</div>
            </Link>
          ))}
        </div>
        {/* Quick stats row */}
        <div className="grid grid-cols-3 gap-3 mt-3">
          <div className="bg-white rounded-xl shadow-sm p-3 flex items-center gap-3">
            <span className="text-2xl">👥</span>
            <div>
              <div className="font-bold text-gray-800">{gameStats.friends}</div>
              <div className="text-xs text-gray-400">Bạn bè</div>
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-sm p-3 flex items-center gap-3">
            <span className="text-2xl">🏆</span>
            <div>
              <div className="font-bold text-gray-800">{gameStats.challengeScore || "—"}</div>
              <div className="text-xs text-gray-400">Challenge hôm nay</div>
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-sm p-3 flex items-center gap-3">
            <span className="text-2xl">🔥</span>
            <div>
              <div className="font-bold text-gray-800">{userData?.streak || 0}</div>
              <div className="text-xs text-gray-400">Ngày streak</div>
            </div>
          </div>
        </div>
      </div>

      {/* Bottom grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5 mb-6">
        {/* Weekly chart */}
        <div className="bg-white rounded-2xl shadow-card p-6">
          <h3 className="text-base font-bold text-gray-700 mb-4">📈 Hoạt động tuần</h3>
          <div className="flex items-end gap-2 h-28">
            {DAYS.map((day, i) => {
              const h = Math.max(4, Math.round((weekData[i] / maxWeek) * 100));
              return (
                <div key={day} className="flex-1 flex flex-col items-center gap-1">
                  <div
                    className="w-full rounded-t-lg bg-gradient-primary transition-all duration-700"
                    style={{ height: `${h}px` }}
                    title={`${weekData[i]} từ`}
                  />
                  <span className="text-xs text-gray-400">{day}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Level path + goal */}
        <div className="bg-white rounded-2xl shadow-card p-6">
          <h3 className="text-base font-bold text-gray-700 mb-4">🗺️ Lộ trình học</h3>
          <div className="flex flex-wrap gap-2 items-center mb-5">
            {LEVELS.map((l, i) => {
              const idx = LEVELS.indexOf(level);
              let cls = "bg-gray-100 text-gray-400";
              if (i < idx) cls = "bg-green-100 text-green-700";
              if (i === idx) cls = "bg-gradient-primary text-white shadow-md";
              return (
                <span key={l}>
                  {i > 0 && <span className="text-gray-300 font-bold mx-1">→</span>}
                  <span className={`px-3 py-1.5 rounded-xl text-xs font-bold ${cls}`}>{l}</span>
                </span>
              );
            })}
          </div>
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-sm text-gray-500">Mục tiêu hôm nay</span>
              <span className="text-sm font-bold text-gray-700">{todayW}/{goal} từ</span>
            </div>
            <div className="w-full bg-gray-100 rounded-full h-2.5">
              <div
                className="bg-gradient-primary h-2.5 rounded-full transition-all duration-500"
                style={{ width: `${goalPct}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Notifications */}
      <div className="bg-white rounded-2xl shadow-card p-6">
        <h3 className="text-base font-bold text-gray-700 mb-4">🔔 Thông báo mới nhất</h3>
        {notifs.length === 0 ? (
          <p className="text-center text-gray-400 text-sm py-6">Chưa có thông báo</p>
        ) : (
          <div className="space-y-0">
            {notifs.map((n) => {
              const [icon, bg] = NOTIF_TYPES[n.type] || NOTIF_TYPES.info;
              const date = n.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || "";
              return (
                <div key={n.id} className="flex gap-3 py-3 border-b border-gray-50 last:border-0">
                  <div className={`w-10 h-10 rounded-xl ${bg} flex items-center justify-center text-lg flex-shrink-0`}>{icon}</div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-sm text-gray-800">{n.title}</div>
                    <div className="text-xs text-gray-500 mt-0.5 truncate">{n.body || n.message}</div>
                    <div className="text-xs text-gray-300 mt-1">{date}</div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
