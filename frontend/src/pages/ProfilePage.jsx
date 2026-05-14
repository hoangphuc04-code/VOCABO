/**
 * ProfilePage.jsx — Hồ sơ người dùng
 */
import { useEffect, useState } from "react";
import { doc, updateDoc, collection, query, where, getDocs } from "firebase/firestore";
import { updateProfile } from "firebase/auth";
import { getFirebaseDb, getFirebaseAuth } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"];

export default function ProfilePage() {
  const { user, userData, setUserData, addToast } = useAppStore((s) => ({
    user: s.user,
    userData: s.userData,
    setUserData: s.setUserData,
    addToast: s.addToast,
  }));

  const [editing, setEditing] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const [saving, setSaving] = useState(false);
  const [stats, setStats] = useState({ sessions: 0, totalWords: 0, decks: 0 });

  useEffect(() => {
    setDisplayName(userData?.displayName || user?.displayName || "");
  }, [userData, user]);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;

    Promise.all([
      getDocs(query(collection(db, "study_sessions"), where("uid", "==", user.uid))),
      getDocs(query(collection(db, "decks"), where("uid", "==", user.uid))),
    ])
      .then(([sessSnap, deckSnap]) => {
        const totalWords = sessSnap.docs.reduce(
          (acc, d) => acc + (d.data().wordsLearned || 0),
          0
        );
        setStats({
          sessions: sessSnap.size,
          totalWords,
          decks: deckSnap.size,
        });
      })
      .catch(() => {});
  }, [user]);

  const handleSave = async () => {
    if (!displayName.trim()) return;
    setSaving(true);
    try {
      const db = getFirebaseDb();
      const auth = getFirebaseAuth();
      if (db && user) {
        await updateDoc(doc(db, "users", user.uid), { displayName: displayName.trim() });
        setUserData({ ...userData, displayName: displayName.trim() });
      }
      if (auth?.currentUser) {
        await updateProfile(auth.currentUser, { displayName: displayName.trim() });
      }
      addToast("Đã cập nhật hồ sơ!", "success");
      setEditing(false);
    } catch (e) {
      addToast("Lỗi khi lưu: " + e.message, "error");
    } finally {
      setSaving(false);
    }
  };

  const name = userData?.displayName || user?.displayName || user?.email || "User";
  const photo = userData?.photoURL || user?.photoURL || "";
  const email = user?.email || "";
  const level = userData?.level || "A1";
  const coins = userData?.coins || 0;
  const diamonds = userData?.diamonds || 0;
  const streak = userData?.streak || 0;
  const wordsLearned = userData?.wordsLearned || 0;
  const levelIdx = LEVELS.indexOf(level);
  const progress = userData?.progress || 0;

  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-black text-gray-800">👤 Hồ sơ</h1>
        <p className="text-gray-500 text-sm mt-1">Thông tin tài khoản của bạn</p>
      </div>

      {/* Profile card */}
      <div className="bg-white rounded-2xl shadow-card p-8 mb-6">
        <div className="flex items-start gap-6">
          {/* Avatar */}
          <div
            className="w-20 h-20 rounded-2xl overflow-hidden flex items-center justify-center font-black text-white text-3xl flex-shrink-0"
            style={{ background: "linear-gradient(135deg,#667eea,#764ba2)" }}
          >
            {photo ? (
              <img src={photo} className="w-full h-full object-cover" alt="" />
            ) : (
              name.charAt(0).toUpperCase()
            )}
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            {editing ? (
              <div className="space-y-3">
                <div>
                  <label className="text-xs font-bold text-gray-500 mb-1 block">
                    Tên hiển thị
                  </label>
                  <input
                    type="text"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl border-2 border-primary text-sm outline-none"
                    placeholder="Nhập tên..."
                  />
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={handleSave}
                    disabled={saving}
                    className="px-5 py-2 rounded-xl bg-gradient-primary text-white text-sm font-bold disabled:opacity-50"
                  >
                    {saving ? "Đang lưu..." : "Lưu"}
                  </button>
                  <button
                    onClick={() => {
                      setEditing(false);
                      setDisplayName(userData?.displayName || user?.displayName || "");
                    }}
                    className="px-5 py-2 rounded-xl border border-gray-200 text-sm font-medium text-gray-600"
                  >
                    Hủy
                  </button>
                </div>
              </div>
            ) : (
              <>
                <div className="flex items-center gap-2 mb-1">
                  <h2 className="text-xl font-black text-gray-800">{name}</h2>
                  <button
                    onClick={() => setEditing(true)}
                    className="text-xs text-primary hover:underline font-medium"
                  >
                    ✏️ Sửa
                  </button>
                </div>
                <p className="text-gray-400 text-sm">{email}</p>
                <div className="flex items-center gap-2 mt-2">
                  <span className="px-2.5 py-1 bg-primary-light text-primary text-xs font-bold rounded-full">
                    Cấp độ {level}
                  </span>
                  <span className="text-xs text-gray-400">
                    {levelIdx >= 0 ? `${levelIdx + 1}/${LEVELS.length}` : ""}
                  </span>
                </div>
              </>
            )}
          </div>
        </div>

        {/* Level progress */}
        <div className="mt-6 pt-6 border-t border-gray-100">
          <div className="flex justify-between mb-2">
            <span className="text-sm text-gray-500">Tiến độ cấp độ</span>
            <span className="text-sm font-bold text-gray-700">
              {Math.round(progress * 100)}%
            </span>
          </div>
          <div className="w-full bg-gray-100 rounded-full h-2.5">
            <div
              className="bg-gradient-primary h-2.5 rounded-full transition-all duration-500"
              style={{ width: `${Math.min(100, Math.round(progress * 100))}%` }}
            />
          </div>
          <div className="flex justify-between mt-1">
            {LEVELS.map((l, i) => (
              <span
                key={l}
                className={`text-xs font-bold ${
                  i <= levelIdx ? "text-primary" : "text-gray-300"
                }`}
              >
                {l}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* Currency & streak */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white rounded-2xl shadow-card p-5 text-center">
          <div className="text-2xl mb-1">🪙</div>
          <div className="text-2xl font-black text-yellow-600">{coins}</div>
          <div className="text-xs text-gray-400 mt-1">Coins</div>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 text-center">
          <div className="text-2xl mb-1">💎</div>
          <div className="text-2xl font-black text-purple-600">{diamonds}</div>
          <div className="text-xs text-gray-400 mt-1">Diamonds</div>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 text-center">
          <div className="text-2xl mb-1">🔥</div>
          <div className="text-2xl font-black text-orange-500">{streak}</div>
          <div className="text-xs text-gray-400 mt-1">Streak</div>
        </div>
      </div>

      {/* Learning stats */}
      <div className="bg-white rounded-2xl shadow-card p-6">
        <h3 className="font-bold text-gray-700 mb-4">📊 Thống kê học tập</h3>
        <div className="grid grid-cols-2 gap-4">
          {[
            { icon: "📚", value: wordsLearned, label: "Từ đã học" },
            { icon: "📅", value: stats.sessions, label: "Buổi học" },
            { icon: "🗂️", value: stats.decks, label: "Bộ thẻ" },
            {
              icon: "🎯",
              value: (userData?.lastTestScore || 0) + "%",
              label: "Điểm test gần nhất",
            },
          ].map(({ icon, value, label }) => (
            <div key={label} className="flex items-center gap-4 p-4 bg-gray-50 rounded-xl">
              <div className="w-10 h-10 rounded-xl bg-white shadow-sm flex items-center justify-center text-xl">
                {icon}
              </div>
              <div>
                <div className="text-xl font-black text-gray-800">{value}</div>
                <div className="text-xs text-gray-400">{label}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
