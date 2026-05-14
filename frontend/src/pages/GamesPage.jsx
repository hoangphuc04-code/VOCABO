/**
 * GamesPage.jsx — Mini Games Hub với Speed Quiz có thể chơi được
 */
import { useEffect, useState, useRef } from "react";
import { collection, query, where, getDocs, addDoc, doc, updateDoc,
  serverTimestamp, orderBy, limit, getDoc, setDoc } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

// ─── Game Data ────────────────────────────────────────────────────────────────
const GAME_WORDS = [
  { word: "apple", meaning: "quả táo", options: ["quả táo", "quả cam", "quả chuối", "quả nho"] },
  { word: "beautiful", meaning: "đẹp", options: ["đẹp", "xấu", "cao", "thấp"] },
  { word: "computer", meaning: "máy tính", options: ["máy tính", "điện thoại", "tivi", "radio"] },
  { word: "elephant", meaning: "con voi", options: ["con voi", "con hổ", "con sư tử", "con gấu"] },
  { word: "freedom", meaning: "tự do", options: ["tự do", "hòa bình", "hạnh phúc", "tình yêu"] },
  { word: "garden", meaning: "khu vườn", options: ["khu vườn", "ngôi nhà", "con đường", "bầu trời"] },
  { word: "hospital", meaning: "bệnh viện", options: ["bệnh viện", "trường học", "nhà hàng", "khách sạn"] },
  { word: "important", meaning: "quan trọng", options: ["quan trọng", "thú vị", "khó khăn", "dễ dàng"] },
  { word: "journey", meaning: "hành trình", options: ["hành trình", "cuộc sống", "ước mơ", "kỷ niệm"] },
  { word: "knowledge", meaning: "kiến thức", options: ["kiến thức", "sức mạnh", "tài năng", "kinh nghiệm"] },
  { word: "language", meaning: "ngôn ngữ", options: ["ngôn ngữ", "văn hóa", "lịch sử", "nghệ thuật"] },
  { word: "mountain", meaning: "ngọn núi", options: ["ngọn núi", "con sông", "biển cả", "đồng bằng"] },
  { word: "nature", meaning: "thiên nhiên", options: ["thiên nhiên", "con người", "xã hội", "khoa học"] },
  { word: "ocean", meaning: "đại dương", options: ["đại dương", "hồ nước", "con suối", "ao cá"] },
  { word: "perfect", meaning: "hoàn hảo", options: ["hoàn hảo", "bình thường", "tệ hại", "kỳ lạ"] },
  { word: "question", meaning: "câu hỏi", options: ["câu hỏi", "câu trả lời", "bài toán", "bài thơ"] },
  { word: "rainbow", meaning: "cầu vồng", options: ["cầu vồng", "mặt trời", "mặt trăng", "ngôi sao"] },
  { word: "science", meaning: "khoa học", options: ["khoa học", "nghệ thuật", "thể thao", "âm nhạc"] },
  { word: "teacher", meaning: "giáo viên", options: ["giáo viên", "bác sĩ", "kỹ sư", "luật sư"] },
  { word: "universe", meaning: "vũ trụ", options: ["vũ trụ", "trái đất", "mặt trăng", "mặt trời"] },
];

// ─── Speed Quiz Game ──────────────────────────────────────────────────────────
function SpeedQuizGame({ level, onFinish }) {
  const { user, userData, setUserData, addToast } = useAppStore(s => ({
    user: s.user, userData: s.userData, setUserData: s.setUserData, addToast: s.addToast
  }));
  const [questions] = useState(() => {
    const shuffled = [...GAME_WORDS].sort(() => Math.random() - 0.5);
    return shuffled.slice(0, 10).map(q => ({
      ...q,
      options: [...q.options].sort(() => Math.random() - 0.5)
    }));
  });
  const [qIdx, setQIdx] = useState(0);
  const [score, setScore] = useState(0);
  const [timeLeft, setTimeLeft] = useState(15);
  const [selected, setSelected] = useState(null);
  const [done, setDone] = useState(false);
  const [results, setResults] = useState([]);
  const timerRef = useRef(null);

  useEffect(() => {
    if (done) return;
    timerRef.current = setInterval(() => {
      setTimeLeft(t => {
        if (t <= 1) { handleAnswer(null); return 15; }
        return t - 1;
      });
    }, 1000);
    return () => clearInterval(timerRef.current);
  }, [qIdx, done]);

  const handleAnswer = async (option) => {
    clearInterval(timerRef.current);
    const q = questions[qIdx];
    const correct = option === q.meaning;
    if (correct) setScore(s => s + 1);
    setSelected(option);
    setResults(r => [...r, { word: q.word, correct, chosen: option, answer: q.meaning }]);

    setTimeout(async () => {
      setSelected(null);
      setTimeLeft(15);
      if (qIdx + 1 >= questions.length) {
        setDone(true);
        const finalScore = score + (correct ? 1 : 0);
        const stars = finalScore >= 9 ? 3 : finalScore >= 7 ? 2 : finalScore >= 5 ? 1 : 0;
        const coins = finalScore * 5;
        // Save to Firestore
        try {
          const db = getFirebaseDb();
          if (db && user) {
            await addDoc(collection(db, "game_progress"), {
              uid: user.uid, gameType: "speed_quiz", level,
              score: finalScore, stars, completedAt: serverTimestamp(),
            });
            const newCoins = (userData?.coins || 0) + coins;
            await updateDoc(doc(db, "users", user.uid), { coins: newCoins });
            setUserData({ ...userData, coins: newCoins });
          }
        } catch (_) {}
        addToast(`+${coins} 🪙 coins!`, "success");
      } else {
        setQIdx(i => i + 1);
      }
    }, 800);
  };

  if (done) {
    const stars = score >= 9 ? 3 : score >= 7 ? 2 : score >= 5 ? 1 : 0;
    return (
      <div className="max-w-lg mx-auto text-center py-8">
        <div className="text-6xl mb-3">{"⭐".repeat(stars) || "💪"}</div>
        <h2 className="text-2xl font-black text-gray-800 mb-1">Kết quả</h2>
        <p className="text-gray-500 mb-6">{score}/10 câu đúng • +{score * 5} 🪙</p>
        <div className="bg-white rounded-2xl shadow-sm p-4 mb-6 text-left space-y-2">
          {results.map((r, i) => (
            <div key={i} className={`flex items-center gap-3 p-2 rounded-xl ${r.correct ? "bg-green-50" : "bg-red-50"}`}>
              <span>{r.correct ? "✅" : "❌"}</span>
              <span className="font-bold text-sm">{r.word}</span>
              <span className="text-sm text-gray-500">→ {r.answer}</span>
              {!r.correct && r.chosen && <span className="text-sm text-red-400 ml-auto">Bạn chọn: {r.chosen}</span>}
            </div>
          ))}
        </div>
        <button onClick={onFinish}
          className="px-6 py-3 bg-gradient-to-r from-yellow-400 to-orange-400 text-white rounded-xl font-bold">
          Quay lại
        </button>
      </div>
    );
  }

  const q = questions[qIdx];
  const timePct = (timeLeft / 15) * 100;

  return (
    <div className="max-w-lg mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <button onClick={onFinish} className="p-2 rounded-xl hover:bg-gray-100 text-gray-500">←</button>
        <div className="text-sm font-bold text-gray-600">⚡ Trả Lời Nhanh — Màn {level}</div>
        <div className="text-sm font-bold text-yellow-600">🪙 {score * 5}</div>
      </div>

      {/* Progress */}
      <div className="flex gap-1 mb-4">
        {questions.map((_, i) => (
          <div key={i} className={`flex-1 h-1.5 rounded-full ${i < qIdx ? "bg-green-400" : i === qIdx ? "bg-yellow-400" : "bg-gray-200"}`} />
        ))}
      </div>

      {/* Timer */}
      <div className="mb-4">
        <div className="flex justify-between text-xs text-gray-400 mb-1">
          <span>Câu {qIdx + 1}/10</span>
          <span className={`font-bold ${timeLeft <= 5 ? "text-red-500" : "text-gray-600"}`}>{timeLeft}s</span>
        </div>
        <div className="w-full bg-gray-100 rounded-full h-2">
          <div className={`h-2 rounded-full transition-all ${timeLeft <= 5 ? "bg-red-400" : "bg-yellow-400"}`}
            style={{ width: `${timePct}%` }} />
        </div>
      </div>

      {/* Question */}
      <div className="bg-white rounded-2xl shadow-sm p-8 text-center mb-6">
        <div className="text-3xl font-black text-gray-800 mb-2">{q.word}</div>
        <div className="text-gray-400 text-sm">Chọn nghĩa đúng</div>
      </div>

      {/* Options */}
      <div className="grid grid-cols-2 gap-3">
        {q.options.map(opt => {
          let cls = "bg-white border-2 border-gray-100 text-gray-700 hover:border-yellow-300";
          if (selected !== null) {
            if (opt === q.meaning) cls = "bg-green-50 border-2 border-green-400 text-green-700";
            else if (opt === selected) cls = "bg-red-50 border-2 border-red-400 text-red-600";
            else cls = "bg-gray-50 border-2 border-gray-100 text-gray-400";
          }
          return (
            <button key={opt} onClick={() => selected === null && handleAnswer(opt)}
              className={`p-4 rounded-xl font-semibold text-sm transition-all ${cls}`}>
              {opt}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ─── Main GamesPage ───────────────────────────────────────────────────────────
export default function GamesPage() {
  const { user, userData } = useAppStore(s => ({ user: s.user, userData: s.userData }));
  const [progress, setProgress] = useState({});
  const [leaderboard, setLeaderboard] = useState([]);
  const [playingGame, setPlayingGame] = useState(null);
  const [playingLevel, setPlayingLevel] = useState(1);
  const [showLevelPicker, setShowLevelPicker] = useState(false);
  const [loading, setLoading] = useState(true);

  const coins = userData?.coins || 0;

  useEffect(() => {
    if (!user) return;
    loadData();
  }, [user]);

  const loadData = async () => {
    const db = getFirebaseDb();
    if (!db || !user) return;
    setLoading(true);
    try {
      const progSnap = await getDocs(query(collection(db, "game_progress"), where("uid", "==", user.uid)));
      const prog = {};
      progSnap.forEach(d => {
        const data = d.data();
        const key = `${data.gameType}_${data.level}`;
        if (!prog[key] || data.score > prog[key].score) prog[key] = data;
      });
      setProgress(prog);

      const lbSnap = await getDocs(query(collection(db, "game_progress"),
        where("gameType", "==", "speed_quiz"), where("level", "==", 1),
        orderBy("score", "desc"), limit(10)));
      const lb = [];
      const seen = new Set();
      for (const d of lbSnap.docs) {
        const data = d.data();
        if (seen.has(data.uid)) continue;
        seen.add(data.uid);
        const userDoc = await getDoc(doc(db, "users", data.uid));
        lb.push({ ...data, displayName: userDoc.data()?.displayName || "Người dùng", photoURL: userDoc.data()?.photoURL || "" });
      }
      setLeaderboard(lb);
    } catch (_) {}
    setLoading(false);
  };

  const getMaxLevel = (gameType) => {
    let max = 0;
    Object.keys(progress).forEach(k => {
      if (k.startsWith(gameType + "_")) {
        const lvl = parseInt(k.split("_")[2]);
        if (!isNaN(lvl) && lvl > max) max = lvl;
      }
    });
    return max;
  };

  const getStars = (gameType, level) => progress[`${gameType}_${level}`]?.stars || 0;

  if (playingGame === "speed_quiz") {
    return <SpeedQuizGame level={playingLevel} onFinish={() => { setPlayingGame(null); loadData(); }} />;
  }

  const GAMES = [
    { id: "speed_quiz", name: "Trả Lời Nhanh", emoji: "⚡", desc: "Chọn nghĩa đúng trong thời gian giới hạn", color: "#FFBE0B", available: true },
    { id: "word_connect", name: "Nối Từ", emoji: "🔗", desc: "Nối từ tiếng Anh với nghĩa tiếng Việt", color: "#667eea", available: false },
    { id: "memory_match", name: "Lật Thẻ", emoji: "🃏", desc: "Tìm cặp thẻ từ vựng trùng nhau", color: "#06D6A0", available: false },
    { id: "word_search", name: "Tìm Từ", emoji: "🔍", desc: "Tìm từ ẩn trong bảng chữ cái", color: "#FF6B35", available: false },
    { id: "anagram", name: "Sắp Xếp Chữ", emoji: "🧩", desc: "Sắp xếp lại chữ cái để tạo thành từ đúng", color: "#5352ED", available: false },
  ];

  return (
    <div className="max-w-3xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-500 to-indigo-500 rounded-2xl p-6 text-white mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-black mb-1">🎮 Mini Games</h1>
          <p className="text-sm opacity-80">Học từ vựng qua trò chơi thú vị</p>
        </div>
        <div className="bg-white/20 rounded-xl px-3 py-1.5 text-sm font-bold">🪙 {coins}</div>
      </div>

      {/* Games */}
      <h3 className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-3">🕹️ Trò chơi</h3>
      <div className="space-y-3 mb-8">
        {GAMES.map(game => {
          const maxLevel = getMaxLevel(game.id);
          const completedLevels = maxLevel;
          const pct = completedLevels / 20;
          return (
            <div key={game.id}
              className={`bg-white rounded-2xl shadow-sm p-5 flex items-center gap-4 ${!game.available ? "opacity-60" : ""}`}>
              <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
                style={{ background: game.color + "22" }}>
                {game.emoji}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-bold text-gray-800">{game.name}</div>
                <div className="text-xs text-gray-500 mb-2">{game.desc}</div>
                <div className="flex items-center gap-2">
                  <div className="flex-1 bg-gray-100 rounded-full h-1.5">
                    <div className="h-1.5 rounded-full transition-all" style={{ width: `${pct * 100}%`, background: game.color }} />
                  </div>
                  <span className="text-xs font-semibold" style={{ color: game.color }}>{completedLevels}/20</span>
                </div>
              </div>
              {game.available ? (
                <button onClick={() => { setPlayingGame(game.id); setPlayingLevel(Math.max(1, maxLevel)); }}
                  className="w-11 h-11 rounded-full flex items-center justify-center text-white text-xl flex-shrink-0"
                  style={{ background: game.color }}>
                  ▶
                </button>
              ) : (
                <div className="px-3 py-1.5 bg-gray-100 text-gray-400 rounded-xl text-xs font-semibold flex-shrink-0">
                  Sắp ra
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Leaderboard */}
      <h3 className="text-sm font-bold text-gray-500 uppercase tracking-wider mb-3">🏆 Bảng xếp hạng</h3>
      <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
        <div className="p-4 border-b border-gray-50">
          <span className="text-sm font-bold text-gray-700">⚡ Trả Lời Nhanh — Màn 1</span>
        </div>
        {loading ? (
          <div className="p-8 text-center text-gray-400">Đang tải...</div>
        ) : leaderboard.length === 0 ? (
          <div className="p-8 text-center text-gray-400">Chưa có dữ liệu</div>
        ) : (
          leaderboard.map((entry, i) => {
            const medals = ["🥇", "🥈", "🥉"];
            const isMe = entry.uid === user?.uid;
            return (
              <div key={i} className={`flex items-center gap-3 px-4 py-3 border-b border-gray-50 last:border-0 ${isMe ? "bg-purple-50" : ""}`}>
                <span className={`w-8 text-center font-bold ${i < 3 ? "text-xl" : "text-sm text-gray-500"}`}>
                  {i < 3 ? medals[i] : i + 1}
                </span>
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-400 to-indigo-400 flex items-center justify-center text-white text-xs font-bold overflow-hidden flex-shrink-0">
                  {entry.photoURL ? <img src={entry.photoURL} className="w-full h-full object-cover" alt="" /> : entry.displayName?.charAt(0)}
                </div>
                <span className={`flex-1 text-sm ${isMe ? "font-bold text-purple-700" : "text-gray-700"}`}>{entry.displayName}</span>
                <div className="flex items-center gap-1">
                  {[0,1,2].map(s => <span key={s} className={s < (entry.stars || 0) ? "text-yellow-400" : "text-gray-200"}>★</span>)}
                  <span className="text-sm font-bold text-gray-700 ml-2">{entry.score}/10</span>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
