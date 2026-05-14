/**
 * DailyChallengePage.jsx — Thử thách hàng ngày + Leaderboard (Tính năng 5)
 * 3 loại: Speed Round (MCQ), Fill in the Blank, Unscramble
 * Xếp hạng toàn server theo ngày
 */
import { useState, useEffect, useRef } from "react";
import {
  collection, query, where, getDocs, setDoc, doc,
  orderBy, limit, onSnapshot, serverTimestamp
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const CHALLENGE_TYPES = ["speedRound", "fillBlank", "unscramble"];
const TYPE_LABELS = { speedRound: "⚡ Speed Round", fillBlank: "✏️ Fill in the Blank", unscramble: "🔀 Unscramble" };
const TYPE_DESC = {
  speedRound: "Chọn nghĩa đúng trong 60 giây",
  fillBlank: "Điền từ tiếng Anh theo nghĩa",
  unscramble: "Sắp xếp chữ cái thành từ đúng",
};

function getTodayKey() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")}`;
}

export default function DailyChallengePage() {
  const { user, userData, addToast } = useAppStore(s => ({ user: s.user, userData: s.userData, addToast: s.addToast }));
  const [phase, setPhase] = useState("pick"); // pick | playing | result
  const [type, setType] = useState("speedRound");
  const [questions, setQuestions] = useState([]);
  const [idx, setIdx] = useState(0);
  const [score, setScore] = useState(0);
  const [answered, setAnswered] = useState(false);
  const [selected, setSelected] = useState(null);
  const [fillInput, setFillInput] = useState("");
  const [scrambled, setScrambled] = useState([]);
  const [arranged, setArranged] = useState([]);
  const [timeLeft, setTimeLeft] = useState(60);
  const [leaderboard, setLeaderboard] = useState([]);
  const timerRef = useRef(null);

  // Auto-pick type based on day
  useEffect(() => {
    const day = new Date().getDate() % 3;
    setType(CHALLENGE_TYPES[day]);
  }, []);

  // Load leaderboard realtime
  useEffect(() => {
    const db = getFirebaseDb();
    if (!db) return;
    const today = getTodayKey();
    const q = query(
      collection(db, "daily_challenge_scores"),
      where("date", "==", today),
      orderBy("score", "desc"),
      limit(10)
    );
    const unsub = onSnapshot(q, snap => {
      setLeaderboard(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });
    return () => unsub();
  }, []);

  const loadQuestions = async () => {
    const db = getFirebaseDb();
    const snap = await getDocs(query(collection(db, "users", user.uid, "learned_words")));
    const words = snap.docs.map(d => d.data()).filter(w => w.word && w.meaning);
    if (words.length < 4) { addToast("Học ít nhất 4 từ để tham gia!", "warning"); return; }
    words.sort(() => Math.random() - 0.5);
    const qs = words.slice(0, 10).map(w => {
      const distractors = words.filter(x => x.word !== w.word).slice(0, 3).map(x => x.meaning);
      const opts = [w.meaning, ...distractors].sort(() => Math.random() - 0.5);
      return { word: w.word, meaning: w.meaning, phonetic: w.phonetic || "", options: opts, correct: opts.indexOf(w.meaning) };
    });
    setQuestions(qs);
    setIdx(0); setScore(0); setAnswered(false); setSelected(null); setFillInput("");
    if (type === "unscramble") buildScramble(qs[0].word);
    setPhase("playing");
    if (type === "speedRound") startTimer();
  };

  const startTimer = () => {
    setTimeLeft(60);
    clearInterval(timerRef.current);
    timerRef.current = setInterval(() => {
      setTimeLeft(t => {
        if (t <= 1) { clearInterval(timerRef.current); finishChallenge(); return 0; }
        return t - 1;
      });
    }, 1000);
  };

  const buildScramble = (word) => {
    const letters = word.toUpperCase().split("").sort(() => Math.random() - 0.5);
    setScrambled(letters);
    setArranged([]);
  };

  const answerMCQ = (i) => {
    if (answered) return;
    const correct = i === questions[idx].correct;
    setAnswered(true); setSelected(i);
    if (correct) setScore(s => s + (type === "speedRound" ? 15 : 10));
    setTimeout(nextQ, 900);
  };

  const submitFill = () => {
    if (answered) return;
    const correct = fillInput.trim().toLowerCase() === questions[idx].word.toLowerCase();
    setAnswered(true);
    if (correct) setScore(s => s + 12);
    setTimeout(nextQ, 1200);
  };

  const submitUnscramble = () => {
    if (answered) return;
    const correct = arranged.join("").toLowerCase() === questions[idx].word.toLowerCase();
    setAnswered(true);
    if (correct) setScore(s => s + 12);
    setTimeout(nextQ, 1200);
  };

  const nextQ = () => {
    if (idx >= questions.length - 1) { finishChallenge(); return; }
    const next = idx + 1;
    setIdx(next); setAnswered(false); setSelected(null); setFillInput("");
    if (type === "unscramble") buildScramble(questions[next].word);
  };

  const finishChallenge = async () => {
    clearInterval(timerRef.current);
    setPhase("result");
    // Save score
    const db = getFirebaseDb();
    const today = getTodayKey();
    await setDoc(doc(db, "daily_challenge_scores", `${user.uid}_${today}`), {
      uid: user.uid,
      displayName: userData?.displayName || user.displayName || "User",
      photoURL: userData?.photoURL || user.photoURL || "",
      score,
      type,
      date: today,
      completedAt: serverTimestamp(),
    }, { merge: true });
    addToast(`🏆 Đã lưu điểm: ${score}`, "success");
  };

  useEffect(() => () => clearInterval(timerRef.current), []);

  const q = questions[idx];
  const myRank = leaderboard.findIndex(l => l.uid === user?.uid);

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-orange-400 to-yellow-500 rounded-2xl p-6 mb-6 text-white">
        <div className="flex items-center gap-3">
          <span className="text-4xl">🏆</span>
          <div>
            <h1 className="text-2xl font-extrabold">Daily Challenge</h1>
            <p className="text-orange-100 text-sm">Thử thách hàng ngày — Cạnh tranh với toàn server!</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main area */}
        <div className="lg:col-span-2">
          {phase === "pick" && (
            <div className="bg-white rounded-2xl shadow-sm p-6">
              <h2 className="font-bold text-gray-800 text-lg mb-4">Chọn loại thử thách hôm nay</h2>
              <div className="space-y-3 mb-6">
                {CHALLENGE_TYPES.map(t => (
                  <button key={t} onClick={() => setType(t)}
                    className={`w-full flex items-center gap-4 p-4 rounded-xl border-2 transition-all text-left ${
                      type === t ? "border-orange-400 bg-orange-50" : "border-gray-100 hover:border-orange-200"
                    }`}>
                    <span className="text-2xl">{TYPE_LABELS[t].split(" ")[0]}</span>
                    <div>
                      <p className="font-bold text-gray-800">{TYPE_LABELS[t].slice(2)}</p>
                      <p className="text-gray-400 text-sm">{TYPE_DESC[t]}</p>
                    </div>
                    {type === t && <span className="ml-auto text-orange-500">✓</span>}
                  </button>
                ))}
              </div>
              <button onClick={loadQuestions}
                className="w-full py-3 bg-gradient-to-r from-orange-400 to-yellow-500 text-white font-bold rounded-xl hover:opacity-90 transition-opacity">
                🚀 Bắt đầu thử thách!
              </button>
            </div>
          )}

          {phase === "playing" && q && (
            <div className="bg-white rounded-2xl shadow-sm p-6">
              {/* Progress + timer */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex-1 bg-gray-100 rounded-full h-2 mr-4">
                  <div className="bg-orange-400 h-2 rounded-full transition-all" style={{ width: `${((idx+1)/questions.length)*100}%` }}/>
                </div>
                <span className="text-sm text-gray-500 font-medium">{idx+1}/{questions.length}</span>
                {type === "speedRound" && (
                  <span className={`ml-3 font-bold text-lg ${timeLeft <= 10 ? "text-red-500" : "text-orange-500"}`}>
                    ⏱ {timeLeft}s
                  </span>
                )}
              </div>

              <div className="flex items-center justify-between mb-4">
                <span className="px-3 py-1 bg-orange-50 text-orange-600 rounded-full text-sm font-semibold">{TYPE_LABELS[type]}</span>
                <span className="font-bold text-indigo-600">🏆 {score} điểm</span>
              </div>

              {/* Question card */}
              <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-xl p-6 mb-6 text-center text-white">
                <p className="text-indigo-200 text-sm mb-2">
                  {type === "speedRound" ? "Nghĩa của từ này là gì?" : type === "fillBlank" ? "Điền từ tiếng Anh có nghĩa:" : "Sắp xếp chữ cái thành từ:"}
                </p>
                <p className="text-3xl font-extrabold">{type === "speedRound" ? q.word : q.meaning}</p>
                {q.phonetic && type === "speedRound" && <p className="text-indigo-200 text-sm italic mt-1">{q.phonetic}</p>}
              </div>

              {/* Answers */}
              {type === "speedRound" && (
                <div className="space-y-3">
                  {q.options.map((opt, i) => {
                    let cls = "border-gray-100 bg-gray-50 hover:border-indigo-300";
                    if (answered) {
                      if (i === q.correct) cls = "border-green-400 bg-green-50";
                      else if (i === selected) cls = "border-red-400 bg-red-50";
                    }
                    return (
                      <button key={i} onClick={() => answerMCQ(i)}
                        className={`w-full p-4 rounded-xl border-2 text-left font-medium transition-all ${cls}`}>
                        {opt}
                      </button>
                    );
                  })}
                </div>
              )}

              {type === "fillBlank" && (
                <div>
                  <div className="flex gap-2">
                    <input value={fillInput} onChange={e => setFillInput(e.target.value)}
                      onKeyDown={e => e.key === "Enter" && submitFill()}
                      disabled={answered} placeholder="Nhập từ tiếng Anh..."
                      className="flex-1 px-4 py-3 border-2 border-gray-200 rounded-xl focus:border-indigo-400 outline-none font-medium"/>
                    <button onClick={submitFill} disabled={answered || !fillInput}
                      className="px-5 py-3 bg-indigo-600 text-white rounded-xl font-semibold disabled:opacity-50">
                      ✓
                    </button>
                  </div>
                  {answered && (
                    <div className={`mt-3 p-3 rounded-xl font-semibold ${fillInput.trim().toLowerCase() === q.word.toLowerCase() ? "bg-green-50 text-green-700" : "bg-red-50 text-red-600"}`}>
                      {fillInput.trim().toLowerCase() === q.word.toLowerCase() ? "✅ Chính xác!" : `❌ Đáp án đúng: ${q.word}`}
                    </div>
                  )}
                </div>
              )}

              {type === "unscramble" && (
                <div>
                  {/* Arranged */}
                  <div className="min-h-14 flex flex-wrap gap-2 p-3 bg-indigo-50 rounded-xl mb-3 border-2 border-indigo-200">
                    {arranged.map((l, i) => (
                      <button key={i} onClick={() => { if (answered) return; setArranged(a => a.filter((_,j)=>j!==i)); setScrambled(s => [...s, l]); }}
                        className="w-10 h-10 bg-indigo-600 text-white font-bold rounded-lg text-lg hover:bg-indigo-700">
                        {l}
                      </button>
                    ))}
                  </div>
                  {/* Scrambled */}
                  <div className="flex flex-wrap gap-2 mb-4">
                    {scrambled.map((l, i) => (
                      <button key={i} onClick={() => { if (answered) return; setScrambled(s => s.filter((_,j)=>j!==i)); setArranged(a => [...a, l]); }}
                        className="w-10 h-10 bg-white border-2 border-indigo-300 text-indigo-600 font-bold rounded-lg text-lg hover:bg-indigo-50">
                        {l}
                      </button>
                    ))}
                  </div>
                  {!answered && (
                    <button onClick={submitUnscramble} disabled={arranged.length === 0}
                      className="w-full py-3 bg-indigo-600 text-white font-bold rounded-xl disabled:opacity-50">
                      Kiểm tra
                    </button>
                  )}
                  {answered && (
                    <div className={`p-3 rounded-xl font-semibold ${arranged.join("").toLowerCase() === q.word.toLowerCase() ? "bg-green-50 text-green-700" : "bg-red-50 text-red-600"}`}>
                      {arranged.join("").toLowerCase() === q.word.toLowerCase() ? "✅ Chính xác!" : `❌ Đáp án đúng: ${q.word}`}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {phase === "result" && (
            <div className="bg-white rounded-2xl shadow-sm p-8 text-center">
              <div className="text-7xl mb-4">{score >= 80 ? "🏆" : score >= 50 ? "🎉" : "💪"}</div>
              <p className="text-5xl font-black text-indigo-600 mb-2">{score}</p>
              <p className="text-gray-500 mb-2">điểm</p>
              <p className="text-gray-600 font-medium mb-6">
                {score >= 80 ? "Xuất sắc! Bạn thật tuyệt vời!" : score >= 50 ? "Tốt lắm! Tiếp tục cố gắng!" : "Cần luyện thêm, đừng nản nhé!"}
              </p>
              {myRank >= 0 && (
                <div className="inline-flex items-center gap-2 px-4 py-2 bg-orange-50 text-orange-600 rounded-full font-semibold mb-6">
                  🏅 Xếp hạng #{myRank + 1} hôm nay
                </div>
              )}
              <button onClick={() => { setPhase("pick"); setScore(0); }}
                className="w-full py-3 bg-gradient-to-r from-orange-400 to-yellow-500 text-white font-bold rounded-xl hover:opacity-90">
                🔄 Thử lại
              </button>
            </div>
          )}
        </div>

        {/* Leaderboard */}
        <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
          <div className="bg-gradient-to-r from-orange-400 to-yellow-500 p-4 text-white">
            <h3 className="font-bold flex items-center gap-2">🏆 Bảng xếp hạng hôm nay</h3>
            <p className="text-orange-100 text-xs">{getTodayKey()}</p>
          </div>
          <div className="divide-y divide-gray-50">
            {leaderboard.length === 0 ? (
              <p className="text-gray-400 text-center py-8 text-sm">Chưa có ai tham gia hôm nay!</p>
            ) : leaderboard.map((l, i) => {
              const medals = ["🥇","🥈","🥉"];
              const isMe = l.uid === user?.uid;
              return (
                <div key={l.id} className={`flex items-center gap-3 px-4 py-3 ${isMe ? "bg-indigo-50" : ""}`}>
                  <span className="text-lg w-6 text-center">{i < 3 ? medals[i] : `${i+1}`}</span>
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-400 to-purple-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                    {l.photoURL ? <img src={l.photoURL} className="w-full h-full rounded-full object-cover" alt=""/> : (l.displayName?.[0] || "U")}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-semibold truncate ${isMe ? "text-indigo-700" : "text-gray-700"}`}>{l.displayName || "User"}</p>
                    <p className="text-xs text-gray-400">{TYPE_LABELS[l.type] || l.type}</p>
                  </div>
                  <span className={`font-bold text-sm ${isMe ? "text-indigo-600" : "text-gray-600"}`}>{l.score}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
