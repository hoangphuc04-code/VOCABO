/**
 * ReviewPage.jsx — Ôn tập từ vựng theo spaced repetition
 */
import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  getDocs,
  doc,
  updateDoc,
  Timestamp,
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

// Spaced repetition intervals (days)
const INTERVALS = [1, 3, 7, 14, 30, 90];

function getNextReview(level, correct) {
  const newLevel = correct ? Math.min(level + 1, INTERVALS.length - 1) : 0;
  const days = INTERVALS[newLevel];
  const next = new Date();
  next.setDate(next.getDate() + days);
  return { nextLevel: newLevel, nextReview: Timestamp.fromDate(next) };
}

function shuffle(arr) {
  return [...arr].sort(() => Math.random() - 0.5);
}

export default function ReviewPage() {
  const { user } = useAppStore((s) => ({ user: s.user }));
  const [cards, setCards] = useState([]);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [options, setOptions] = useState([]);
  const [selected, setSelected] = useState(null);
  const [correct, setCorrect] = useState(0);
  const [wrong, setWrong] = useState(0);
  const [loading, setLoading] = useState(true);
  const [done, setDone] = useState(false);
  const [allVocabs, setAllVocabs] = useState([]);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;
    setLoading(true);

    getDocs(query(collection(db, "vocabularies"), where("uid", "==", user.uid)))
      .then((snap) => {
        const all = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        setAllVocabs(all);
        const now = new Date();
        const due = all.filter((v) => {
          if (!v.nextReview) return true;
          const nr = v.nextReview?.toDate?.();
          return !nr || nr <= now;
        });
        setCards(shuffle(due).slice(0, 20));
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [user]);

  useEffect(() => {
    if (cards.length === 0 || currentIdx >= cards.length) return;
    buildOptions(cards[currentIdx]);
  }, [cards, currentIdx, allVocabs]);

  const buildOptions = (card) => {
    const correct = card.meaning || card.definition || "—";
    const pool = allVocabs
      .filter((v) => v.id !== card.id && (v.meaning || v.definition))
      .map((v) => v.meaning || v.definition);
    const distractors = shuffle(pool).slice(0, 3);
    setOptions(shuffle([correct, ...distractors]));
    setSelected(null);
  };

  const handleAnswer = async (opt) => {
    if (selected !== null) return;
    setSelected(opt);
    const card = cards[currentIdx];
    const isCorrect = opt === (card.meaning || card.definition);
    if (isCorrect) setCorrect((c) => c + 1);
    else setWrong((w) => w + 1);

    // Update Firestore
    const db = getFirebaseDb();
    if (db && card.id) {
      const { nextLevel, nextReview } = getNextReview(card.srLevel || 0, isCorrect);
      try {
        await updateDoc(doc(db, "vocabularies", card.id), {
          srLevel: nextLevel,
          nextReview,
          lastReviewed: Timestamp.now(),
        });
      } catch (_) {}
    }

    setTimeout(() => {
      if (currentIdx + 1 >= cards.length) setDone(true);
      else {
        setCurrentIdx((i) => i + 1);
      }
    }, 1200);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-10 h-10 border-4 border-primary-light border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (cards.length === 0) {
    return (
      <div className="max-w-md mx-auto mt-10">
        <div className="bg-white rounded-2xl shadow-card p-12 text-center">
          <div className="text-6xl mb-4">🎉</div>
          <h2 className="text-xl font-black text-gray-800 mb-2">Tuyệt vời!</h2>
          <p className="text-gray-500 text-sm">
            Không có từ nào cần ôn tập hôm nay. Hãy quay lại sau!
          </p>
        </div>
      </div>
    );
  }

  if (done) {
    const total = correct + wrong;
    const pct = total > 0 ? Math.round((correct / total) * 100) : 0;
    return (
      <div className="max-w-md mx-auto mt-10">
        <div className="bg-white rounded-2xl shadow-card p-8 text-center">
          <div className="text-6xl mb-4">{pct >= 70 ? "🏆" : "💪"}</div>
          <h2 className="text-2xl font-black text-gray-800 mb-2">Ôn tập xong!</h2>
          <p className="text-gray-500 mb-6">Kết quả phiên ôn tập của bạn</p>
          <div className="grid grid-cols-3 gap-4 mb-6">
            <div className="bg-green-50 rounded-xl p-4">
              <div className="text-2xl font-black text-green-600">{correct}</div>
              <div className="text-xs text-green-500 mt-1">Đúng</div>
            </div>
            <div className="bg-red-50 rounded-xl p-4">
              <div className="text-2xl font-black text-red-500">{wrong}</div>
              <div className="text-xs text-red-400 mt-1">Sai</div>
            </div>
            <div className="bg-primary-light rounded-xl p-4">
              <div className="text-2xl font-black text-primary">{pct}%</div>
              <div className="text-xs text-primary/70 mt-1">Chính xác</div>
            </div>
          </div>
          <button
            onClick={() => window.location.reload()}
            className="w-full py-3 rounded-xl bg-gradient-primary text-white font-bold"
          >
            🔄 Ôn tập lại
          </button>
        </div>
      </div>
    );
  }

  const card = cards[currentIdx];
  const correctAnswer = card.meaning || card.definition;
  const progress = Math.round((currentIdx / cards.length) * 100);

  return (
    <div className="max-w-lg mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-black text-gray-800">🔁 Ôn tập</h1>
        <p className="text-gray-500 text-sm mt-1">
          {cards.length} từ cần ôn tập hôm nay
        </p>
      </div>

      {/* Progress */}
      <div className="flex items-center gap-3 mb-6">
        <div className="flex-1 bg-gray-100 rounded-full h-2">
          <div
            className="bg-gradient-primary h-2 rounded-full transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>
        <span className="text-sm text-gray-500 font-medium">
          {currentIdx + 1}/{cards.length}
        </span>
      </div>

      {/* Card */}
      <div className="bg-white rounded-2xl shadow-card p-8 mb-6 text-center">
        <div className="text-xs text-gray-400 uppercase tracking-widest mb-3">
          Nghĩa của từ này là gì?
        </div>
        <div className="text-4xl font-black text-gray-800 mb-2">
          {card.word || card.term || "—"}
        </div>
        {card.phonetic && (
          <div className="text-gray-400 text-sm">{card.phonetic}</div>
        )}
        {card.partOfSpeech && (
          <span className="inline-block mt-2 px-2 py-0.5 bg-primary-light text-primary text-xs rounded-full font-medium">
            {card.partOfSpeech}
          </span>
        )}
      </div>

      {/* Options */}
      <div className="grid grid-cols-1 gap-3">
        {options.map((opt, i) => {
          let cls =
            "w-full py-4 px-5 rounded-xl border-2 text-left font-medium text-sm transition-all ";
          if (selected === null) {
            cls += "border-gray-200 bg-white hover:border-primary hover:bg-primary-light text-gray-700";
          } else if (opt === correctAnswer) {
            cls += "border-green-400 bg-green-50 text-green-700";
          } else if (opt === selected) {
            cls += "border-red-400 bg-red-50 text-red-600";
          } else {
            cls += "border-gray-100 bg-gray-50 text-gray-400";
          }
          return (
            <button key={i} className={cls} onClick={() => handleAnswer(opt)}>
              <span className="font-bold mr-2 text-gray-400">
                {["A", "B", "C", "D"][i]}.
              </span>
              {opt}
            </button>
          );
        })}
      </div>

      {/* Stats */}
      <div className="flex justify-center gap-6 mt-6 text-sm">
        <span className="text-green-600 font-bold">✓ {correct} đúng</span>
        <span className="text-red-500 font-bold">✗ {wrong} sai</span>
      </div>
    </div>
  );
}
