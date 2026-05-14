/**
 * SmartSrsPage.jsx — Smart SRS với AI Insight (Tính năng 3)
 * Phân tích pattern sai → điều chỉnh interval → gợi ý cải thiện
 */
import { useState, useEffect } from "react";
import {
  collection, query, where, getDocs, doc, updateDoc,
  addDoc, serverTimestamp, Timestamp, orderBy, limit
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const GROQ_KEY = import.meta.env.VITE_GROQ_API_KEY ?? "";

async function analyzeWeakWords(mistakes) {
  if (mistakes.length === 0) return null;
  const mistakeText = mistakes.slice(0, 30).map(m =>
    `- Từ: "${m.word}" (${m.meaning}) → Sai: "${m.wrongAnswer}"`
  ).join("\n");
  try {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${GROQ_KEY}` },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content: `Phân tích lỗi sai của học viên và đưa ra nhận xét.
Trả lời JSON: {"weakWords":["word1","word2"],"confusedPairs":[{"word1":"affect","word2":"effect","reason":"..."}],"pattern":"Mô tả pattern lỗi","tip":"Lời khuyên cụ thể"}
KHÔNG thêm text nào ngoài JSON.`,
          },
          { role: "user", content: `Phân tích lỗi sai:\n${mistakeText}` },
        ],
        max_tokens: 400,
        temperature: 0.3,
      }),
    });
    const data = await res.json();
    const reply = data.choices?.[0]?.message?.content || "";
    const s = reply.indexOf("{"), e = reply.lastIndexOf("}");
    if (s !== -1 && e !== -1) return JSON.parse(reply.slice(s, e + 1));
  } catch (_) {}
  return null;
}

// SM-2 algorithm
function computeNextReview(card, quality) {
  let ef = card.easeFactor || 2.5;
  let interval = card.interval || 1;
  let reps = card.repetitions || 0;
  if (quality >= 3) {
    if (reps === 0) interval = 1;
    else if (reps === 1) interval = 6;
    else interval = Math.round(interval * ef);
    reps++;
  } else {
    reps = 0; interval = 1;
  }
  ef = Math.max(1.3, ef + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  const nextReview = new Date(Date.now() + interval * 86400000);
  return { easeFactor: ef, interval, repetitions: reps, nextReview, strength: (quality / 5).toFixed(2) };
}

export default function SmartSrsPage() {
  const { user, addToast } = useAppStore(s => ({ user: s.user, addToast: s.addToast }));
  const [dueCards, setDueCards] = useState([]);
  const [stats, setStats] = useState({ total: 0, mastered: 0, learning: 0, newWords: 0, dueToday: 0 });
  const [insight, setInsight] = useState(null);
  const [loadingInsight, setLoadingInsight] = useState(false);
  const [loading, setLoading] = useState(true);
  const [reviewing, setReviewing] = useState(false);
  const [reviewIdx, setReviewIdx] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [sessionScore, setSessionScore] = useState({ correct: 0, wrong: 0 });
  const [done, setDone] = useState(false);

  useEffect(() => {
    if (!user) return;
    loadData();
  }, [user]);

  const loadData = async () => {
    setLoading(true);
    const db = getFirebaseDb();
    const now = new Date();

    const [progressSnap, mistakesSnap] = await Promise.all([
      getDocs(query(collection(db, "vocabulary_progress"), where("uid", "==", user.uid))),
      getDocs(query(collection(db, "srs_mistakes"), where("uid", "==", user.uid), orderBy("timestamp", "desc"), limit(30))),
    ]);

    let mastered = 0, learning = 0, newWords = 0, dueToday = 0;
    const due = [];

    progressSnap.forEach(d => {
      const data = d.data();
      const s = data.strength || 0.5;
      if (s >= 0.8) mastered++;
      else if (s >= 0.4) learning++;
      else newWords++;
      const nextReview = data.nextReview?.toDate?.() || now;
      if (nextReview <= now) {
        dueToday++;
        due.push({ id: d.id, ...data });
      }
    });

    setStats({ total: progressSnap.size, mastered, learning, newWords, dueToday });
    setDueCards(due.slice(0, 20));

    // Analyze mistakes
    const mistakes = mistakesSnap.docs.map(d => d.data());
    if (mistakes.length >= 5) {
      setLoadingInsight(true);
      const result = await analyzeWeakWords(mistakes);
      setInsight(result);
      setLoadingInsight(false);
    }

    setLoading(false);
  };

  const startReview = () => {
    if (dueCards.length === 0) { addToast("Không có từ nào cần ôn hôm nay!", "info"); return; }
    setReviewing(true);
    setReviewIdx(0);
    setFlipped(false);
    setSessionScore({ correct: 0, wrong: 0 });
    setDone(false);
  };

  const handleAnswer = async (quality) => {
    const card = dueCards[reviewIdx];
    const db = getFirebaseDb();
    const next = computeNextReview(card, quality);

    // Update progress
    await updateDoc(doc(db, "vocabulary_progress", card.id), {
      ...next,
      nextReview: Timestamp.fromDate(next.nextReview),
      lastReview: serverTimestamp(),
    }).catch(() => {});

    // Record mistake if wrong
    if (quality < 3) {
      setSessionScore(s => ({ ...s, wrong: s.wrong + 1 }));
      await addDoc(collection(db, "srs_mistakes"), {
        uid: user.uid,
        wordId: card.wordId,
        word: card.word,
        meaning: card.meaning,
        wrongAnswer: "không nhớ",
        correctAnswer: card.meaning,
        timestamp: serverTimestamp(),
      }).catch(() => {});
    } else {
      setSessionScore(s => ({ ...s, correct: s.correct + 1 }));
    }

    if (reviewIdx >= dueCards.length - 1) {
      setDone(true);
      addToast(`✅ Ôn xong! ${sessionScore.correct + (quality >= 3 ? 1 : 0)} đúng`, "success");
    } else {
      setReviewIdx(i => i + 1);
      setFlipped(false);
    }
  };

  const applyFix = async () => {
    if (!insight?.weakWords?.length) return;
    const db = getFirebaseDb();
    const snap = await getDocs(query(collection(db, "vocabulary_progress"), where("uid", "==", user.uid)));
    let count = 0;
    for (const d of snap.docs) {
      if (insight.weakWords.includes(d.data().word)) {
        await updateDoc(d.ref, {
          interval: 1,
          nextReview: Timestamp.fromDate(new Date()),
          easeFactor: 2.0,
        });
        count++;
      }
    }
    addToast(`✅ Đã đặt lại lịch ôn cho ${count} từ yếu`, "success");
    loadData();
  };

  const card = dueCards[reviewIdx];

  if (reviewing && !done && card) {
    return (
      <div className="max-w-lg mx-auto">
        <div className="flex items-center justify-between mb-4">
          <button onClick={() => setReviewing(false)} className="text-gray-400 hover:text-gray-600">← Thoát</button>
          <span className="text-sm text-gray-500">{reviewIdx + 1}/{dueCards.length}</span>
          <span className="text-sm font-semibold text-green-600">✓ {sessionScore.correct} · ✗ {sessionScore.wrong}</span>
        </div>
        <div className="bg-gray-100 rounded-full h-2 mb-6">
          <div className="bg-indigo-500 h-2 rounded-full transition-all" style={{ width: `${((reviewIdx+1)/dueCards.length)*100}%` }}/>
        </div>

        {/* Flashcard */}
        <div className="bg-white rounded-2xl shadow-sm p-8 text-center mb-6 cursor-pointer min-h-48 flex flex-col items-center justify-center"
          onClick={() => setFlipped(f => !f)}>
          {!flipped ? (
            <>
              <p className="text-3xl font-extrabold text-gray-800 mb-2">{card.word}</p>
              {card.phonetic && <p className="text-gray-400 italic">{card.phonetic}</p>}
              <p className="text-gray-300 text-sm mt-4">Nhấn để xem nghĩa</p>
            </>
          ) : (
            <>
              <p className="text-2xl font-bold text-indigo-600 mb-2">{card.meaning}</p>
              {card.example && <p className="text-gray-500 text-sm italic mt-2">"{card.example}"</p>}
            </>
          )}
        </div>

        {flipped && (
          <div className="grid grid-cols-3 gap-3">
            <button onClick={() => handleAnswer(1)}
              className="py-3 bg-red-50 text-red-600 border-2 border-red-200 rounded-xl font-semibold hover:bg-red-100 transition-colors">
              😕 Không nhớ
            </button>
            <button onClick={() => handleAnswer(3)}
              className="py-3 bg-yellow-50 text-yellow-600 border-2 border-yellow-200 rounded-xl font-semibold hover:bg-yellow-100 transition-colors">
              🤔 Khó nhớ
            </button>
            <button onClick={() => handleAnswer(5)}
              className="py-3 bg-green-50 text-green-600 border-2 border-green-200 rounded-xl font-semibold hover:bg-green-100 transition-colors">
              😊 Dễ nhớ
            </button>
          </div>
        )}
      </div>
    );
  }

  if (done) {
    return (
      <div className="max-w-lg mx-auto text-center py-12">
        <div className="text-7xl mb-4">🎉</div>
        <h2 className="text-2xl font-extrabold text-gray-800 mb-2">Ôn tập hoàn thành!</h2>
        <p className="text-gray-500 mb-6">{sessionScore.correct} đúng · {sessionScore.wrong} sai</p>
        <button onClick={() => { setReviewing(false); loadData(); }}
          className="px-8 py-3 bg-indigo-600 text-white font-bold rounded-xl hover:bg-indigo-700">
          Xem thống kê
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl p-6 mb-6 text-white">
        <div className="flex items-center gap-3 mb-4">
          <span className="text-4xl">🧠</span>
          <div>
            <h1 className="text-2xl font-extrabold">Smart SRS</h1>
            <p className="text-indigo-100 text-sm">Ôn tập thông minh với AI phân tích điểm yếu</p>
          </div>
        </div>
        {/* Stats */}
        <div className="grid grid-cols-5 gap-2">
          {[
            { label: "Tổng từ", value: stats.total, emoji: "📚" },
            { label: "Thuộc", value: stats.mastered, emoji: "⭐" },
            { label: "Đang học", value: stats.learning, emoji: "📖" },
            { label: "Mới", value: stats.newWords, emoji: "🌱" },
            { label: "Cần ôn", value: stats.dueToday, emoji: "🔔" },
          ].map(s => (
            <div key={s.label} className="bg-white/20 rounded-xl p-2 text-center">
              <p className="text-lg">{s.emoji}</p>
              <p className="text-lg font-extrabold">{s.value}</p>
              <p className="text-indigo-200 text-xs">{s.label}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Review button */}
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <h2 className="font-bold text-gray-800 text-lg mb-4">📅 Ôn tập hôm nay</h2>
          {loading ? (
            <div className="flex justify-center py-8"><div className="w-8 h-8 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"/></div>
          ) : dueCards.length === 0 ? (
            <div className="text-center py-8">
              <span className="text-4xl block mb-2">✅</span>
              <p className="text-gray-500 font-medium">Không có từ nào cần ôn hôm nay!</p>
              <p className="text-gray-400 text-sm mt-1">Quay lại sau để ôn tập tiếp</p>
            </div>
          ) : (
            <>
              <div className="flex items-center gap-3 p-4 bg-indigo-50 rounded-xl mb-4">
                <span className="text-3xl">🔔</span>
                <div>
                  <p className="font-bold text-indigo-700">{dueCards.length} từ cần ôn</p>
                  <p className="text-indigo-500 text-sm">Dựa trên thuật toán SM-2</p>
                </div>
              </div>
              <button onClick={startReview}
                className="w-full py-3 bg-indigo-600 text-white font-bold rounded-xl hover:bg-indigo-700 transition-colors">
                🚀 Bắt đầu ôn tập
              </button>
            </>
          )}
        </div>

        {/* AI Insight */}
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <h2 className="font-bold text-gray-800 text-lg mb-4">🧠 AI Insight</h2>
          {loadingInsight ? (
            <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-xl">
              <div className="w-6 h-6 border-2 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"/>
              <p className="text-gray-500 text-sm">Meow đang phân tích lỗi sai...</p>
            </div>
          ) : !insight ? (
            <div className="text-center py-6 text-gray-400">
              <span className="text-4xl block mb-2">📊</span>
              <p className="text-sm">Làm bài kiểm tra để nhận phân tích AI</p>
            </div>
          ) : (
            <div className="space-y-3">
              {insight.pattern && (
                <div className="flex gap-2 p-3 bg-blue-50 rounded-xl">
                  <span>📊</span>
                  <p className="text-blue-700 text-sm">{insight.pattern}</p>
                </div>
              )}
              {insight.confusedPairs?.slice(0, 2).map((p, i) => (
                <div key={i} className="p-3 bg-orange-50 rounded-xl">
                  <p className="font-semibold text-orange-700 text-sm">"{p.word1}" vs "{p.word2}"</p>
                  <p className="text-orange-500 text-xs mt-0.5">{p.reason}</p>
                </div>
              ))}
              {insight.tip && (
                <div className="flex gap-2 p-3 bg-indigo-50 rounded-xl">
                  <span>💡</span>
                  <p className="text-indigo-700 text-sm">{insight.tip}</p>
                </div>
              )}
              {insight.weakWords?.length > 0 && (
                <button onClick={applyFix}
                  className="w-full py-2.5 bg-indigo-600 text-white font-semibold rounded-xl text-sm hover:bg-indigo-700 transition-colors">
                  🔧 Ôn lại {insight.weakWords.length} từ yếu ngay
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
