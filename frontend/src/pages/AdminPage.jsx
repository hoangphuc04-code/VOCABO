/**
 * AdminPage.jsx — Trang quản trị nâng cấp (chỉ admin)
 * Quản lý: Word Stories, Daily Challenge, AI Conversations, SRS Insights,
 *          Games, Farm/House, Friends/Chat
 */
import { useEffect, useState } from "react";
import {
  collection, getDocs, query, orderBy, limit, where,
  deleteDoc, doc, updateDoc
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const ADMIN_EMAILS = ["admin@vocabo.app", "admin@example.com"];

const TABS = [
  { id: "overview",      label: "📊 Tổng quan" },
  { id: "users",         label: "👥 Người dùng" },
  { id: "word_stories",  label: "📖 Word Stories" },
  { id: "challenges",    label: "🏆 Daily Challenge" },
  { id: "conversations", label: "🤖 AI Conversations" },
  { id: "srs",           label: "🧠 SRS Insights" },
  { id: "games",         label: "🎮 Games" },
  { id: "social",        label: "👥 Social" },
];

export default function AdminPage() {
  const { user } = useAppStore((s) => ({ user: s.user }));
  const [tab, setTab] = useState("overview");
  const [stats, setStats] = useState({
    totalUsers: 0, totalTopics: 0, totalSessions: 0,
    wordStories: 0, challengeScores: 0, conversations: 0, srsMistakes: 0,
    gameProgress: 0, friendships: 0, chatMessages: 0,
  });
  const [recentUsers, setRecentUsers] = useState([]);
  const [wordStories, setWordStories] = useState([]);
  const [challenges, setChallenges] = useState([]);
  const [conversations, setConversations] = useState([]);
  const [srsMistakes, setSrsMistakes] = useState([]);
  const [gameProgress, setGameProgress] = useState([]);
  const [friendships, setFriendships] = useState([]);
  const [loading, setLoading] = useState(true);

  const isAdmin = user?.email && ADMIN_EMAILS.includes(user.email.toLowerCase());

  useEffect(() => {
    if (!isAdmin) return;
    const db = getFirebaseDb();
    if (!db) return;
    setLoading(true);

    Promise.all([
      getDocs(query(collection(db, "users"), orderBy("createdAt", "desc"), limit(20))),
      getDocs(collection(db, "topics")),
      getDocs(collection(db, "study_sessions")),
      getDocs(query(collection(db, "word_stories"), orderBy("createdAt", "desc"), limit(50))),
      getDocs(query(collection(db, "daily_challenge_scores"), orderBy("score", "desc"), limit(50))),
      getDocs(query(collection(db, "conversation_sessions"), orderBy("createdAt", "desc"), limit(50))),
      getDocs(query(collection(db, "srs_mistakes"), orderBy("timestamp", "desc"), limit(100))),
      getDocs(query(collection(db, "game_progress"), orderBy("completedAt", "desc"), limit(100))),
      getDocs(query(collection(db, "friendships"), limit(100))),
    ]).then(([usersSnap, topicsSnap, sessSnap, storiesSnap, challengeSnap, convSnap, srsSnap, gameSnap, friendSnap]) => {
      setStats({
        totalUsers: usersSnap.size,
        totalTopics: topicsSnap.size,
        totalSessions: sessSnap.size,
        wordStories: storiesSnap.size,
        challengeScores: challengeSnap.size,
        conversations: convSnap.size,
        srsMistakes: srsSnap.size,
        gameProgress: gameSnap.size,
        friendships: friendSnap.size,
        chatMessages: 0,
      });
      setRecentUsers(usersSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setWordStories(storiesSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setChallenges(challengeSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setConversations(convSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setSrsMistakes(srsSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setGameProgress(gameSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setFriendships(friendSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [isAdmin]);

  const deleteItem = async (collectionName, id) => {
    const db = getFirebaseDb();
    await deleteDoc(doc(db, collectionName, id));
    if (collectionName === "word_stories") setWordStories(s => s.filter(x => x.id !== id));
    if (collectionName === "game_progress") setGameProgress(s => s.filter(x => x.id !== id));
  };

  const toggleBanUser = async (userId, isBanned) => {
    const db = getFirebaseDb();
    await updateDoc(doc(db, "users", userId), { banned: !isBanned });
    setRecentUsers(s => s.map(u => u.id === userId ? { ...u, banned: !isBanned } : u));
  };

  if (!isAdmin) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <div className="text-6xl mb-4">🔒</div>
        <h2 className="text-xl font-bold text-gray-700 mb-2">Không có quyền truy cập</h2>
        <p className="text-gray-400">Trang này chỉ dành cho Admin</p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-gray-800 to-gray-900 rounded-2xl p-6 mb-6 text-white">
        <div className="flex items-center gap-3">
          <span className="text-4xl">🛡️</span>
          <div>
            <h1 className="text-2xl font-extrabold">Admin Panel</h1>
            <p className="text-gray-400 text-sm">VOCABO — Quản trị hệ thống</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex flex-wrap gap-2 mb-6 bg-white rounded-2xl shadow-sm p-2">
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${
              tab === t.id ? "bg-gray-800 text-white shadow" : "text-gray-500 hover:bg-gray-100"
            }`}>{t.label}</button>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><div className="w-10 h-10 border-4 border-gray-200 border-t-gray-800 rounded-full animate-spin"/></div>
      ) : (
        <>
          {/* Overview */}
          {tab === "overview" && (
            <div>
              {/* Core stats */}
              <h3 className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-3">📊 Thống kê chính</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                {[
                  { label: "Người dùng", value: stats.totalUsers, emoji: "👥", color: "blue" },
                  { label: "Chủ đề", value: stats.totalTopics, emoji: "📚", color: "green" },
                  { label: "Phiên học", value: stats.totalSessions, emoji: "📖", color: "orange" },
                  { label: "Kết bạn", value: stats.friendships, emoji: "🤝", color: "purple" },
                ].map(s => (
                  <div key={s.label} className="bg-white rounded-2xl shadow-sm p-5">
                    <div className="text-2xl mb-2">{s.emoji}</div>
                    <div className="text-2xl font-extrabold text-gray-800">{s.value}</div>
                    <div className="text-gray-400 text-sm">{s.label}</div>
                  </div>
                ))}
              </div>

              {/* New features stats */}
              <h3 className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-3">🚀 Tính năng mới</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                {[
                  { label: "Word Stories", value: stats.wordStories, emoji: "📖", color: "indigo" },
                  { label: "Challenge", value: stats.challengeScores, emoji: "🏆", color: "yellow" },
                  { label: "AI Chats", value: stats.conversations, emoji: "🤖", color: "violet" },
                  { label: "SRS Mistakes", value: stats.srsMistakes, emoji: "📊", color: "red" },
                ].map(s => (
                  <div key={s.label} className="bg-white rounded-2xl shadow-sm p-5">
                    <div className="text-2xl mb-2">{s.emoji}</div>
                    <div className="text-2xl font-extrabold text-gray-800">{s.value}</div>
                    <div className="text-gray-400 text-sm">{s.label}</div>
                  </div>
                ))}
              </div>

              {/* Gamification stats */}
              <h3 className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-3">🎮 Gamification</h3>
              <div className="grid grid-cols-2 md:grid-cols-2 gap-4 mb-6">
                {[
                  { label: "Game Sessions", value: stats.gameProgress, emoji: "🎮", color: "purple" },
                  { label: "Friendships", value: stats.friendships, emoji: "👥", color: "blue" },
                ].map(s => (
                  <div key={s.label} className="bg-white rounded-2xl shadow-sm p-5">
                    <div className="text-2xl mb-2">{s.emoji}</div>
                    <div className="text-2xl font-extrabold text-gray-800">{s.value}</div>
                    <div className="text-gray-400 text-sm">{s.label}</div>
                  </div>
                ))}
              </div>

              {/* Recent users table */}
              <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
                <div className="p-5 border-b border-gray-50">
                  <h3 className="font-bold text-gray-800">👥 Người dùng mới nhất</h3>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50">
                      <tr>
                        {["Tên", "Email", "Cấp độ", "Từ đã học", "Streak", "Ngày tham gia"].map(h => (
                          <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{h}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-50">
                      {recentUsers.map(u => (
                        <tr key={u.id} className="hover:bg-gray-50">
                          <td className="px-4 py-3">
                            <div className="flex items-center gap-2">
                              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-400 to-purple-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                                {u.photoURL ? <img src={u.photoURL} className="w-full h-full rounded-full object-cover" alt=""/> : (u.displayName?.[0] || "U")}
                              </div>
                              <span className="font-medium text-gray-800">{u.displayName || "Ẩn danh"}</span>
                              {u.banned && <span className="px-1.5 py-0.5 bg-red-100 text-red-600 text-xs rounded-full font-bold">Bị khóa</span>}
                            </div>
                          </td>
                          <td className="px-4 py-3 text-gray-500">{u.email}</td>
                          <td className="px-4 py-3">
                            <span className="px-2 py-0.5 bg-indigo-50 text-indigo-600 rounded-full text-xs font-bold">{u.level || "A1"}</span>
                          </td>
                          <td className="px-4 py-3 text-gray-600">{u.wordsLearned || 0}</td>
                          <td className="px-4 py-3 text-orange-500 font-semibold">🔥 {u.streak || 0}</td>
                          <td className="px-4 py-3 text-gray-400 text-xs">
                            {u.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* Users tab */}
          {tab === "users" && (
            <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
              <div className="p-5 border-b border-gray-50 flex items-center justify-between">
                <h3 className="font-bold text-gray-800">👥 Tất cả người dùng ({recentUsers.length})</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      {["Tên", "Email", "Cấp độ", "Từ đã học", "Streak", "Ngày tham gia", "Hành động"].map(h => (
                        <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {recentUsers.map(u => (
                      <tr key={u.id} className={`hover:bg-gray-50 ${u.banned ? "bg-red-50" : ""}`}>
                        <td className="px-4 py-3 font-medium text-gray-800">
                          <div className="flex items-center gap-2">
                            {u.displayName || "Ẩn danh"}
                            {u.banned && <span className="px-1.5 py-0.5 bg-red-100 text-red-600 text-xs rounded-full font-bold">Bị khóa</span>}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-gray-500">{u.email}</td>
                        <td className="px-4 py-3"><span className="px-2 py-0.5 bg-indigo-50 text-indigo-600 rounded-full text-xs font-bold">{u.level || "A1"}</span></td>
                        <td className="px-4 py-3">{u.wordsLearned || 0}</td>
                        <td className="px-4 py-3 text-orange-500">🔥 {u.streak || 0}</td>
                        <td className="px-4 py-3 text-gray-400 text-xs">{u.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}</td>
                        <td className="px-4 py-3">
                          <div className="flex gap-2">
                            <button
                              onClick={() => toggleBanUser(u.id, u.banned)}
                              className={`px-2 py-1 rounded-lg text-xs font-semibold transition-colors ${
                                u.banned
                                  ? "bg-green-50 text-green-600 hover:bg-green-100"
                                  : "bg-orange-50 text-orange-600 hover:bg-orange-100"
                              }`}>
                              {u.banned ? "🔓 Mở khóa" : "🔒 Khóa"}
                            </button>
                            <button
                              onClick={() => deleteItem("users", u.id)}
                              className="px-2 py-1 bg-red-50 text-red-500 rounded-lg text-xs font-semibold hover:bg-red-100">
                              🗑️
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Word Stories */}
          {tab === "word_stories" && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-bold text-gray-800">📖 Word Stories ({wordStories.length})</h3>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {wordStories.map(s => (
                  <div key={s.id} className="bg-white rounded-2xl shadow-sm p-5">
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-bold text-gray-800">{s.title}</h4>
                      <button onClick={() => deleteItem("word_stories", s.id)}
                        className="text-red-400 hover:text-red-600 text-sm ml-2 flex-shrink-0">🗑️</button>
                    </div>
                    <div className="flex flex-wrap gap-1 mb-2">
                      {(s.words || []).map(w => (
                        <span key={w} className="px-2 py-0.5 bg-indigo-50 text-indigo-600 rounded-full text-xs">{w}</span>
                      ))}
                    </div>
                    <p className="text-gray-500 text-sm line-clamp-2">{s.story}</p>
                    <p className="text-gray-300 text-xs mt-2">{s.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Daily Challenge */}
          {tab === "challenges" && (
            <div>
              <h3 className="font-bold text-gray-800 mb-4">🏆 Daily Challenge Scores ({challenges.length})</h3>
              <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      {["Hạng", "Người dùng", "Điểm", "Loại", "Ngày"].map(h => (
                        <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {challenges.map((c, i) => (
                      <tr key={c.id} className="hover:bg-gray-50">
                        <td className="px-4 py-3 text-lg">{i < 3 ? ["🥇","🥈","🥉"][i] : i+1}</td>
                        <td className="px-4 py-3 font-medium text-gray-800">{c.displayName || "User"}</td>
                        <td className="px-4 py-3 font-bold text-indigo-600">{c.score}</td>
                        <td className="px-4 py-3 text-gray-500">{c.type}</td>
                        <td className="px-4 py-3 text-gray-400 text-xs">{c.date}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* AI Conversations */}
          {tab === "conversations" && (
            <div>
              <h3 className="font-bold text-gray-800 mb-4">🤖 AI Conversations ({conversations.length})</h3>
              {/* Scenario breakdown */}
              <div className="grid grid-cols-2 md:grid-cols-5 gap-3 mb-6">
                {["freeChat","restaurant","jobInterview","shopping","travel"].map(s => {
                  const count = conversations.filter(c => c.scenario === s).length;
                  const emojis = { freeChat:"💬", restaurant:"🍽️", jobInterview:"💼", shopping:"🛍️", travel:"✈️" };
                  return (
                    <div key={s} className="bg-white rounded-xl shadow-sm p-4 text-center">
                      <div className="text-2xl mb-1">{emojis[s]}</div>
                      <div className="font-bold text-gray-800">{count}</div>
                      <div className="text-gray-400 text-xs">{s}</div>
                    </div>
                  );
                })}
              </div>
              <div className="bg-white rounded-2xl shadow-sm divide-y divide-gray-50">
                {conversations.slice(0, 30).map(c => (
                  <div key={c.id} className="flex items-center gap-3 px-5 py-3">
                    <span className="text-xl">{{ freeChat:"💬", restaurant:"🍽️", jobInterview:"💼", shopping:"🛍️", travel:"✈️" }[c.scenario] || "🤖"}</span>
                    <div className="flex-1">
                      <p className="text-sm font-medium text-gray-700">{c.scenario}</p>
                      <p className="text-xs text-gray-400">{c.messageCount || 0} tin nhắn</p>
                    </div>
                    <p className="text-xs text-gray-300">{c.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* SRS Insights */}
          {tab === "srs" && (
            <div>
              <h3 className="font-bold text-gray-800 mb-4">🧠 SRS Mistakes ({srsMistakes.length})</h3>
              {/* Top wrong words */}
              <div className="bg-white rounded-2xl shadow-sm p-5 mb-4">
                <h4 className="font-semibold text-gray-700 mb-4">Top từ bị sai nhiều nhất</h4>
                {(() => {
                  const counts = {};
                  srsMistakes.forEach(m => { counts[m.word] = (counts[m.word] || 0) + 1; });
                  const sorted = Object.entries(counts).sort((a,b) => b[1]-a[1]).slice(0, 15);
                  const max = sorted[0]?.[1] || 1;
                  return sorted.map(([word, count]) => (
                    <div key={word} className="flex items-center gap-3 mb-2">
                      <span className="w-24 text-sm font-semibold text-gray-700 flex-shrink-0">{word}</span>
                      <div className="flex-1 bg-gray-100 rounded-full h-4 overflow-hidden">
                        <div className="bg-red-400 h-4 rounded-full transition-all"
                          style={{ width: `${(count/max)*100}%` }}/>
                      </div>
                      <span className="text-sm font-bold text-red-500 w-8 text-right">{count}x</span>
                    </div>
                  ));
                })()}
              </div>
            </div>
          )}

          {/* Games tab */}
          {tab === "games" && (
            <div>
              <h3 className="font-bold text-gray-800 mb-4">🎮 Game Progress ({gameProgress.length})</h3>

              {/* Game type breakdown */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                {["speed_quiz", "word_connect", "memory_match", "anagram"].map(type => {
                  const count = gameProgress.filter(g => g.gameType === type).length;
                  const emojis = { speed_quiz: "⚡", word_connect: "🔗", memory_match: "🃏", anagram: "🧩" };
                  const labels = { speed_quiz: "Speed Quiz", word_connect: "Nối Từ", memory_match: "Lật Thẻ", anagram: "Sắp Xếp" };
                  return (
                    <div key={type} className="bg-white rounded-2xl shadow-sm p-5 text-center">
                      <div className="text-3xl mb-2">{emojis[type]}</div>
                      <div className="text-2xl font-extrabold text-gray-800">{count}</div>
                      <div className="text-gray-400 text-sm">{labels[type]}</div>
                    </div>
                  );
                })}
              </div>

              {/* Top players */}
              <div className="bg-white rounded-2xl shadow-sm overflow-hidden mb-4">
                <div className="p-5 border-b border-gray-50">
                  <h4 className="font-bold text-gray-800">🏆 Top người chơi (Speed Quiz)</h4>
                </div>
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      {["Hạng", "UID", "Game", "Màn", "Điểm", "Sao", "Thời gian"].map(h => (
                        <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {gameProgress
                      .filter(g => g.gameType === "speed_quiz")
                      .sort((a, b) => (b.score || 0) - (a.score || 0))
                      .slice(0, 20)
                      .map((g, i) => (
                        <tr key={g.id} className="hover:bg-gray-50">
                          <td className="px-4 py-3 text-lg">{i < 3 ? ["🥇","🥈","🥉"][i] : i+1}</td>
                          <td className="px-4 py-3 text-gray-500 text-xs font-mono">{g.uid?.slice(0,8)}...</td>
                          <td className="px-4 py-3 text-gray-600">⚡ Speed Quiz</td>
                          <td className="px-4 py-3 text-gray-600">Màn {g.level || 1}</td>
                          <td className="px-4 py-3 font-bold text-indigo-600">{g.score}/10</td>
                          <td className="px-4 py-3 text-yellow-500">{"⭐".repeat(g.stars || 0)}</td>
                          <td className="px-4 py-3 text-gray-400 text-xs">
                            {g.completedAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}
                          </td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>

              {/* Delete old game records */}
              <div className="bg-white rounded-2xl shadow-sm p-5">
                <h4 className="font-semibold text-gray-700 mb-3">🗑️ Quản lý dữ liệu game</h4>
                <p className="text-gray-400 text-sm mb-3">Tổng {gameProgress.length} bản ghi game progress trong hệ thống.</p>
                <div className="flex flex-wrap gap-2">
                  {gameProgress.slice(0, 10).map(g => (
                    <div key={g.id} className="flex items-center gap-2 px-3 py-1.5 bg-gray-50 rounded-xl text-xs">
                      <span>⚡ {g.gameType} Lv{g.level} — {g.score}/10</span>
                      <button onClick={() => deleteItem("game_progress", g.id)}
                        className="text-red-400 hover:text-red-600">✕</button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Social tab */}
          {tab === "social" && (
            <div>
              <h3 className="font-bold text-gray-800 mb-4">👥 Social — Bạn bè & Chat</h3>

              {/* Stats */}
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-6">
                {[
                  { label: "Kết bạn", value: friendships.length, emoji: "🤝" },
                  { label: "Người dùng", value: stats.totalUsers, emoji: "👥" },
                  { label: "Tỷ lệ kết bạn", value: stats.totalUsers > 0 ? Math.round((friendships.length / stats.totalUsers) * 100) + "%" : "0%", emoji: "📊" },
                ].map(s => (
                  <div key={s.label} className="bg-white rounded-2xl shadow-sm p-5 text-center">
                    <div className="text-3xl mb-2">{s.emoji}</div>
                    <div className="text-2xl font-extrabold text-gray-800">{s.value}</div>
                    <div className="text-gray-400 text-sm">{s.label}</div>
                  </div>
                ))}
              </div>

              {/* Friendships list */}
              <div className="bg-white rounded-2xl shadow-sm overflow-hidden mb-4">
                <div className="p-5 border-b border-gray-50">
                  <h4 className="font-bold text-gray-800">🤝 Danh sách kết bạn ({friendships.length})</h4>
                </div>
                {friendships.length === 0 ? (
                  <div className="p-8 text-center text-gray-400">
                    <span className="text-4xl block mb-2">👥</span>
                    Chưa có kết bạn nào
                  </div>
                ) : (
                  <div className="divide-y divide-gray-50">
                    {friendships.slice(0, 20).map(f => {
                      const uids = f.uids || [];
                      return (
                        <div key={f.id} className="flex items-center gap-3 px-5 py-3">
                          <span className="text-xl">🤝</span>
                          <div className="flex-1">
                            <p className="text-sm font-medium text-gray-700 font-mono text-xs">
                              {uids[0]?.slice(0, 8)}... ↔ {uids[1]?.slice(0, 8)}...
                            </p>
                            <p className="text-xs text-gray-400">
                              {f.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}
                            </p>
                          </div>
                          <button onClick={() => deleteItem("friendships", f.id)}
                            className="text-red-400 hover:text-red-600 text-sm">🗑️</button>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Users with most friends */}
              <div className="bg-white rounded-2xl shadow-sm p-5">
                <h4 className="font-semibold text-gray-700 mb-3">📊 Phân tích mạng xã hội</h4>
                {(() => {
                  const friendCount = {};
                  friendships.forEach(f => {
                    (f.uids || []).forEach(uid => {
                      friendCount[uid] = (friendCount[uid] || 0) + 1;
                    });
                  });
                  const sorted = Object.entries(friendCount).sort((a,b) => b[1]-a[1]).slice(0, 10);
                  if (sorted.length === 0) return <p className="text-gray-400 text-sm">Chưa có dữ liệu</p>;
                  return (
                    <div className="space-y-2">
                      {sorted.map(([uid, count]) => (
                        <div key={uid} className="flex items-center gap-3">
                          <span className="text-xs font-mono text-gray-400 w-24 flex-shrink-0">{uid.slice(0,8)}...</span>
                          <div className="flex-1 bg-gray-100 rounded-full h-3 overflow-hidden">
                            <div className="bg-purple-400 h-3 rounded-full"
                              style={{ width: `${(count / (sorted[0]?.[1] || 1)) * 100}%` }}/>
                          </div>
                          <span className="text-xs font-bold text-purple-600 w-12 text-right">{count} bạn</span>
                        </div>
                      ))}
                    </div>
                  );
                })()}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
