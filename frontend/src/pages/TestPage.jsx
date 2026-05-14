/**
 * TestPage.jsx — Kiểm tra trắc nghiệm 4 đáp án
 */
import { useEffect, useState, useRef } from "react";
import { collection, query, where, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const TOTAL_QUESTIONS = 10;
const TIME_LIMIT = 600; // 10 minutes in seconds

function shuffle(arr) {
  return [...arr].sort(() => Math.random() - 0.5);
}

export default function TestPage() {
  const { user } = useAppStore((s) => ({ user: s.user }));
  const [questions, setQuestions] = useState([]);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [answers, setAnswers] = useState({});
  const [timeLeft, setTimeLeft] = useState(TIME_LIMIT);
  const [started, setStarted] = useState(false);
  const [finished, setFinished] = useState(false);
  const [loading, setLoading] = useState(true);
  const timerRef = useRef(null);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;
    setLoading(true);
    getDocs(query(collection(db, "vocabularies"), where("uid", "==", user.uid)))
      .then((snap) => {
        const all = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        if (all.length < 4) {
          setQuestions([]);
          return;
        }
        const pool = shuffle(all).slice(0, TOTAL_QUESTIONS);
        const qs = pool.map((card) => {
          const correct = card.meaning || card.definition || "—";
          const distractors = shuffle(
            all
              .filter((v) => v.id !== card.id && (v.meaning || v.definition))
              .map((v) => v.meaning || v.definition)
          ).slice(0, 3);
          return {
            id: card.id,
            word: card.word || card.term || "—",
            phonetic: card.phonetic || "",
            correct,
            options: shuffle([correct, ...distractors]),
          };
        });
        setQuestions(qs);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [user]);

  // Timer
  useEffect(() => {
    if (!started || finished) return;
    timerRef.current = setInterval(() => {
      setTimeLeft((t) => {
        if (t <= 1) {
          clearInterval(timerRef.current);
          setFinished(true);
          return 0;
        }
        return t - 1;
      });
    }, 1000);
    return () => clearInterval(timerRef.current);
  }, [started, finished]);

  const handleAnswer = (opt) => {
    if (answers[currentIdx] !== undefined) return;
    setAnswers((prev) => ({ ...prev, [currentIdx]: opt }));
    setTimeout(() => {
      if (currentIdx + 1 >= questions.length) {
        clearInterval(timerRef.current);
        setFinished(true);
      } else {
        setCurrentIdx((i) => i + 1);
      }
    }, 800);
  };

  const formatTime = (s) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, "0")}`;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-10 h-10 border-4 border-primary-light border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (questions.length === 0) {
    return (
      <div className="max-w-md mx-auto mt-10">
        <div className="bg-white rounded-2xl shadow-card p-12 text-center">
          <div className="text-6xl mb-4">📭</div>
          <h2 className="text-xl font-black text-gray-800 mb-2">Chưa đủ từ vựng</h2>
          <p className="text-gray-500 text-sm">
            Bạn cần ít nhất 4 từ vựng để làm bài kiểm tra.
          </p>
        </div>
      </div>
    );
  }

  // Start screen
  if (!started) {
    return (
      <div className="max-w-md mx-auto mt-10">
        <div className="bg-white rounded-2xl shadow-card p-8 text-center">
          <div className="text-6xl mb-4">📝</div>
          <h2 className="text-2xl font-black text-gray-800 mb-2">Bài kiểm tra</h2>
          <p className="text-gray-500 mb-6">
            {questions.length} câu hỏi • Thời gian: 10 phút
          </p>
          <div className="grid grid-cols-2 gap-4 mb-6 text-sm">
            <div className="bg-primary-light rounded-xl p-4">
              <div className="text-2xl font-black text-primary">{questions.length}</div>
              <div className="text-primary/70 mt-1">Câu hỏi</div>
            </div>
            <div className="bg-orange-50 rounded-xl p-4">
              <div className="text-2xl font-black text-orange-500">10:00</div>
              <div className="text-orange-400 mt-1">Thời gian</div>
            </div>
          </div>
          <button
            onClick={() => setStarted(true)}
            className="w-full py-4 rounded-xl bg-gradient-primary text-white font-bold text-base"
          >
            🚀 Bắt đầu kiểm tra
          </button>
        </div>
      </div>
    );
  }

  // Results screen
  if (finished) {
    const score = questions.reduce((acc, q, i) => {
      return acc + (answers[i] === q.correct ? 1 : 0);
    }, 0);
    const pct = Math.round((score / questions.length) * 100);
    const grade =
      pct >= 90 ? "A" : pct >= 80 ? "B" : pct >= 70 ? "C" : pct >= 60 ? "D" : "F";
    const gradeColor =
      pct >= 70 ? "text-green-600" : pct >= 50 ? "text-yellow-500" : "text-red-500";

    return (
      <div className="max-w-lg mx-auto">
        <div className="bg-white rounded-2xl shadow-card p-8 mb-6 text-center">
          <div className="text-6xl mb-4">{pct >= 70 ? "🏆" : pct >= 50 ? "📊" : "😅"}</div>
          <h2 className="text-2xl font-black text-gray-800 mb-1">Kết quả bài kiểm tra</h2>
          <div className={`text-6xl font-black my-4 ${gradeColor}`}>{grade}</div>
          <div className="grid grid-cols-3 gap-4 mb-6">
            <div className="bg-green-50 rounded-xl p-4">
              <div className="text-2xl font-black text-green-600">{score}</div>
              <div className="text-xs text-green-500 mt-1">Đúng</div>
            </div>
            <div className="bg-red-50 rounded-xl p-4">
              <div className="text-2xl font-black text-red-500">
                {questions.length - score}
              </div>
              <div className="text-xs text-red-400 mt-1">Sai</div>
            </div>
            <div className="bg-primary-light rounded-xl p-4">
              <div className="text-2xl font-black text-primary">{pct}%</div>
              <div className="text-xs text-primary/70 mt-1">Điểm</div>
            </div>
          </div>
          <button
            onClick={() => window.location.reload()}
            className="w-full py-3 rounded-xl bg-gradient-primary text-white font-bold"
          >
            🔄 Làm lại
          </button>
        </div>

        {/* Review answers */}
        <div className="bg-white rounded-2xl shadow-card p-6">
          <h3 className="font-bold text-gray-700 mb-4">📋 Xem lại đáp án</h3>
          <div className="space-y-3">
            {questions.map((q, i) => {
              const userAns = answers[i];
              const isCorrect = userAns === q.correct;
              return (
                <div
                  key={i}
                  className={`p-4 rounded-xl border-2 ${
                    isCorrect ? "border-green-200 bg-green-50" : "border-red-200 bg-red-50"
                  }`}
                >
                  <div className="flex items-start gap-2">
                    <span className={`font-bold ${isCorrect ? "text-green-600" : "text-red-500"}`}>
                      {isCorrect ? "✓" : "✗"}
                    </span>
                    <div className="flex-1">
                      <div className="font-bold text-gray-800 text-sm">
                        {i + 1}. {q.word}
                      </div>
                      {!isCorrect && (
                        <div className="text-xs text-red-500 mt-1">
                          Bạn chọn: {userAns || "Không trả lời"}
                        </div>
                      )}
                      <div className="text-xs text-green-600 mt-0.5">
                        Đáp án: {q.correct}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // Quiz screen
  const q = questions[currentIdx];
  const userAnswer = answers[currentIdx];
  const progress = Math.round((currentIdx / questions.length) * 100);
  const timerPct = (timeLeft / TIME_LIMIT) * 100;
  const timerColor = timeLeft < 60 ? "bg-red-500" : timeLeft < 180 ? "bg-yellow-400" : "bg-gradient-primary";

  return (
    <div className="max-w-lg mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="text-sm font-bold text-gray-600">
          Câu {currentIdx + 1}/{questions.length}
        </div>
        <div
          className={`px-4 py-1.5 rounded-full text-sm font-bold ${
            timeLeft < 60 ? "bg-red-100 text-red-600" : "bg-primary-light text-primary"
          }`}
        >
          ⏱ {formatTime(timeLeft)}
        </div>
      </div>

      {/* Progress */}
      <div className="w-full bg-gray-100 rounded-full h-2 mb-6">
        <div
          className="bg-gradient-primary h-2 rounded-full transition-all duration-500"
          style={{ width: `${progress}%` }}
        />
      </div>

      {/* Timer bar */}
      <div className="w-full bg-gray-100 rounded-full h-1.5 mb-6">
        <div
          className={`${timerColor} h-1.5 rounded-full transition-all duration-1000`}
          style={{ width: `${timerPct}%` }}
        />
      </div>

      {/* Question */}
      <div className="bg-white rounded-2xl shadow-card p-8 mb-6 text-center">
        <div className="text-xs text-gray-400 uppercase tracking-widest mb-3">
          Nghĩa của từ này là gì?
        </div>
        <div className="text-4xl font-black text-gray-800 mb-2">{q.word}</div>
        {q.phonetic && <div className="text-gray-400 text-sm">{q.phonetic}</div>}
      </div>

      {/* Options */}
      <div className="grid grid-cols-1 gap-3">
        {q.options.map((opt, i) => {
          let cls =
            "w-full py-4 px-5 rounded-xl border-2 text-left font-medium text-sm transition-all ";
          if (userAnswer === undefined) {
            cls += "border-gray-200 bg-white hover:border-primary hover:bg-primary-light text-gray-700";
          } else if (opt === q.correct) {
            cls += "border-green-400 bg-green-50 text-green-700";
          } else if (opt === userAnswer) {
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
    </div>
  );
}
