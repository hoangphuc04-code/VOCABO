/**
 * GrammarPage.jsx — Bài học ngữ pháp
 */
import { useEffect, useState } from "react";
import { collection, getDocs, orderBy, query } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";

const LEVEL_COLORS = {
  A1: "bg-blue-100 text-blue-700",
  A2: "bg-green-100 text-green-700",
  B1: "bg-yellow-100 text-yellow-700",
  B2: "bg-purple-100 text-purple-700",
  C1: "bg-red-100 text-red-700",
  C2: "bg-teal-100 text-teal-700",
};

export default function GrammarPage() {
  const [lessons, setLessons] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);
  const [quizAnswers, setQuizAnswers] = useState({});
  const [quizSubmitted, setQuizSubmitted] = useState(false);

  useEffect(() => {
    const db = getFirebaseDb();
    if (!db) return;
    setLoading(true);
    getDocs(query(collection(db, "grammar_lessons"), orderBy("order", "asc")))
      .then((snap) => {
        setLessons(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
      })
      .catch(() => {
        // Fallback demo data
        setLessons([
          {
            id: "1",
            title: "Thì hiện tại đơn",
            level: "A1",
            description: "Diễn tả hành động thường xuyên, thói quen hoặc sự thật hiển nhiên.",
            content: `**Cấu trúc:**\n- Khẳng định: S + V(s/es)\n- Phủ định: S + do/does + not + V\n- Nghi vấn: Do/Does + S + V?\n\n**Ví dụ:**\n- She works every day.\n- He doesn't like coffee.\n- Do they play football?`,
            exercises: [
              { question: "She ___ (go) to school every day.", answer: "goes" },
              { question: "They ___ (not/eat) meat.", answer: "don't eat" },
            ],
            order: 1,
          },
          {
            id: "2",
            title: "Thì hiện tại tiếp diễn",
            level: "A1",
            description: "Diễn tả hành động đang xảy ra tại thời điểm nói.",
            content: `**Cấu trúc:**\n- Khẳng định: S + am/is/are + V-ing\n- Phủ định: S + am/is/are + not + V-ing\n- Nghi vấn: Am/Is/Are + S + V-ing?\n\n**Ví dụ:**\n- I am studying English now.\n- She is not sleeping.\n- Are they playing?`,
            exercises: [
              { question: "I ___ (study) right now.", answer: "am studying" },
              { question: "She ___ (not/sleep) at the moment.", answer: "is not sleeping" },
            ],
            order: 2,
          },
          {
            id: "3",
            title: "Thì quá khứ đơn",
            level: "A2",
            description: "Diễn tả hành động đã xảy ra và kết thúc trong quá khứ.",
            content: `**Cấu trúc:**\n- Khẳng định: S + V-ed (regular) / V2 (irregular)\n- Phủ định: S + did + not + V\n- Nghi vấn: Did + S + V?\n\n**Ví dụ:**\n- She visited Paris last year.\n- He didn't come to the party.\n- Did you see that movie?`,
            exercises: [
              { question: "She ___ (visit) Paris last year.", answer: "visited" },
              { question: "He ___ (not/come) to the party.", answer: "didn't come" },
            ],
            order: 3,
          },
        ]);
      })
      .finally(() => setLoading(false));
  }, []);

  const openLesson = (lesson) => {
    setSelected(lesson);
    setQuizAnswers({});
    setQuizSubmitted(false);
  };

  const handleQuizSubmit = () => {
    setQuizSubmitted(true);
  };

  const renderContent = (content) => {
    if (!content) return null;
    return content.split("\n").map((line, i) => {
      if (line.startsWith("**") && line.endsWith("**")) {
        return (
          <p key={i} className="font-bold text-gray-800 mt-4 mb-1">
            {line.replace(/\*\*/g, "")}
          </p>
        );
      }
      if (line.startsWith("- ")) {
        return (
          <li key={i} className="text-gray-600 text-sm ml-4 list-disc">
            {line.slice(2)}
          </li>
        );
      }
      return line ? (
        <p key={i} className="text-gray-600 text-sm">
          {line}
        </p>
      ) : (
        <br key={i} />
      );
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-10 h-10 border-4 border-primary-light border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  // Lesson detail view
  if (selected) {
    const exercises = selected.exercises || [];
    const score = quizSubmitted
      ? exercises.filter(
          (ex, i) =>
            (quizAnswers[i] || "").trim().toLowerCase() ===
            ex.answer.toLowerCase()
        ).length
      : 0;

    return (
      <div className="max-w-2xl mx-auto">
        <button
          onClick={() => setSelected(null)}
          className="flex items-center gap-2 text-gray-500 hover:text-primary mb-6 text-sm font-medium"
        >
          ← Quay lại danh sách
        </button>

        <div className="bg-white rounded-2xl shadow-card p-8 mb-6">
          <div className="flex items-start justify-between mb-4">
            <div>
              <span
                className={`inline-block px-2 py-0.5 rounded-full text-xs font-bold mb-2 ${
                  LEVEL_COLORS[selected.level] || "bg-gray-100 text-gray-600"
                }`}
              >
                {selected.level}
              </span>
              <h1 className="text-2xl font-black text-gray-800">{selected.title}</h1>
              <p className="text-gray-500 text-sm mt-1">{selected.description}</p>
            </div>
          </div>

          <div className="border-t border-gray-100 pt-6">
            <h3 className="font-bold text-gray-700 mb-3">📖 Nội dung bài học</h3>
            <div className="bg-gray-50 rounded-xl p-5 space-y-1">
              {renderContent(selected.content)}
            </div>
          </div>
        </div>

        {exercises.length > 0 && (
          <div className="bg-white rounded-2xl shadow-card p-8">
            <h3 className="font-bold text-gray-700 mb-4">✏️ Bài tập</h3>
            <div className="space-y-4">
              {exercises.map((ex, i) => {
                const userAns = (quizAnswers[i] || "").trim().toLowerCase();
                const correct = ex.answer.toLowerCase();
                const isCorrect = userAns === correct;
                return (
                  <div key={i} className="p-4 bg-gray-50 rounded-xl">
                    <p className="text-sm font-medium text-gray-700 mb-2">
                      {i + 1}. {ex.question}
                    </p>
                    <input
                      type="text"
                      value={quizAnswers[i] || ""}
                      onChange={(e) =>
                        setQuizAnswers((prev) => ({ ...prev, [i]: e.target.value }))
                      }
                      disabled={quizSubmitted}
                      placeholder="Nhập đáp án..."
                      className={`w-full px-4 py-2 rounded-xl border text-sm outline-none transition-colors ${
                        quizSubmitted
                          ? isCorrect
                            ? "border-green-400 bg-green-50 text-green-700"
                            : "border-red-400 bg-red-50 text-red-600"
                          : "border-gray-200 focus:border-primary"
                      }`}
                    />
                    {quizSubmitted && !isCorrect && (
                      <p className="text-xs text-green-600 mt-1">
                        Đáp án đúng: <strong>{ex.answer}</strong>
                      </p>
                    )}
                  </div>
                );
              })}
            </div>

            {!quizSubmitted ? (
              <button
                onClick={handleQuizSubmit}
                className="mt-5 w-full py-3 rounded-xl bg-gradient-primary text-white font-bold"
              >
                Nộp bài
              </button>
            ) : (
              <div className="mt-5 p-4 bg-primary-light rounded-xl text-center">
                <div className="text-2xl font-black text-primary">
                  {score}/{exercises.length}
                </div>
                <div className="text-sm text-primary/70 mt-1">
                  {score === exercises.length ? "🎉 Hoàn hảo!" : "💪 Cố gắng hơn nhé!"}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    );
  }

  // Lesson list
  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-black text-gray-800">📖 Ngữ pháp</h1>
        <p className="text-gray-500 text-sm mt-1">
          {lessons.length} bài học ngữ pháp
        </p>
      </div>

      {lessons.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-card p-12 text-center">
          <div className="text-6xl mb-4">📭</div>
          <h3 className="text-lg font-bold text-gray-700 mb-2">Chưa có bài học</h3>
          <p className="text-gray-400 text-sm">Nội dung đang được cập nhật.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {lessons.map((lesson) => (
            <button
              key={lesson.id}
              onClick={() => openLesson(lesson)}
              className="bg-white rounded-2xl shadow-card p-6 text-left hover:-translate-y-1 hover:shadow-card-hover transition-all"
            >
              <div className="flex items-start justify-between mb-3">
                <div className="w-12 h-12 rounded-2xl bg-primary-light flex items-center justify-center text-2xl">
                  📖
                </div>
                <span
                  className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                    LEVEL_COLORS[lesson.level] || "bg-gray-100 text-gray-600"
                  }`}
                >
                  {lesson.level || "—"}
                </span>
              </div>
              <h3 className="font-bold text-gray-800 text-base mb-1">{lesson.title}</h3>
              <p className="text-xs text-gray-400 line-clamp-2">{lesson.description}</p>
              {lesson.exercises?.length > 0 && (
                <div className="mt-3 text-xs text-primary font-medium">
                  ✏️ {lesson.exercises.length} bài tập
                </div>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
