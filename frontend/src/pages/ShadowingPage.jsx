/**
 * ShadowingPage.jsx — Shadowing Mode (Tính năng 7)
 * Phát audio câu ví dụ → người dùng đọc theo → AI chấm điểm cả câu
 */
import { useState, useEffect, useRef } from "react";
import { collection, query, where, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const GROQ_KEY = import.meta.env.VITE_GROQ_API_KEY ?? "";

async function assessSentence(spoken, target) {
  try {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${GROQ_KEY}` },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content: `Bạn là chuyên gia đánh giá phát âm tiếng Anh.
So sánh câu người dùng nói với câu gốc và đánh giá.
Trả lời JSON: {"score":85,"comment":"Nhận xét ngắn tiếng Việt","tip":"Gợi ý cải thiện"}
KHÔNG thêm text nào ngoài JSON.`,
          },
          { role: "user", content: `Câu gốc: "${target}"\nNgười dùng nói: "${spoken}"` },
        ],
        max_tokens: 150,
        temperature: 0.3,
      }),
    });
    const data = await res.json();
    const reply = data.choices?.[0]?.message?.content || "";
    const s = reply.indexOf("{"), e = reply.lastIndexOf("}");
    if (s !== -1 && e !== -1) return JSON.parse(reply.slice(s, e + 1));
  } catch (_) {}
  return { score: 50, comment: "Không thể đánh giá", tip: "" };
}

function scoreColor(s) {
  if (s >= 80) return "text-green-600";
  if (s >= 60) return "text-yellow-600";
  return "text-red-500";
}

function scoreBg(s) {
  if (s >= 80) return "bg-green-50 border-green-200";
  if (s >= 60) return "bg-yellow-50 border-yellow-200";
  return "bg-red-50 border-red-200";
}

export default function ShadowingPage() {
  const { user, addToast } = useAppStore(s => ({ user: s.user, addToast: s.addToast }));
  const [sentences, setSentences] = useState([]);
  const [idx, setIdx] = useState(0);
  const [phase, setPhase] = useState("ready"); // ready | playing | listening | assessing | result
  const [result, setResult] = useState(null);
  const [spokenText, setSpokenText] = useState("");
  const [scores, setScores] = useState([]);
  const [loading, setLoading] = useState(true);
  const [topic, setTopic] = useState("Tất cả");
  const [topics, setTopics] = useState(["Tất cả"]);
  const recognitionRef = useRef(null);
  const synthRef = useRef(window.speechSynthesis);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    getDocs(query(collection(db, "users", user.uid, "learned_words"))).then(snap => {
      const words = snap.docs.map(d => d.data()).filter(w => w.example && w.example.length > 10);
      const topicSet = new Set(["Tất cả"]);
      words.forEach(w => topicSet.add(w.topicName || "Khác"));
      setTopics([...topicSet]);
      const sents = words.map(w => ({
        text: w.example,
        translation: w.exampleVi || "",
        word: w.word,
        topic: w.topicName || "Khác",
      }));
      sents.sort(() => Math.random() - 0.5);
      setSentences(sents);
      setLoading(false);
    });
  }, [user]);

  const filtered = sentences.filter(s => topic === "Tất cả" || s.topic === topic);

  const playSentence = () => {
    if (!filtered[idx]) return;
    setPhase("playing");
    setResult(null);
    const utt = new SpeechSynthesisUtterance(filtered[idx].text);
    utt.lang = "en-US";
    utt.rate = 0.85;
    utt.onend = () => setPhase("ready");
    synthRef.current.cancel();
    synthRef.current.speak(utt);
  };

  const startListening = () => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) { addToast("Trình duyệt không hỗ trợ nhận diện giọng nói", "error"); return; }
    setPhase("listening");
    setSpokenText("");
    const rec = new SpeechRecognition();
    rec.lang = "en-US";
    rec.continuous = false;
    rec.interimResults = false;
    rec.onresult = async (e) => {
      const spoken = e.results[0][0].transcript;
      setSpokenText(spoken);
      setPhase("assessing");
      const assessment = await assessSentence(spoken, filtered[idx].text);
      setResult({ ...assessment, spoken });
      setScores(s => [...s, assessment.score]);
      setPhase("result");
    };
    rec.onerror = () => { setPhase("ready"); addToast("Không nhận được giọng nói", "warning"); };
    rec.onend = () => { if (phase === "listening") setPhase("ready"); };
    recognitionRef.current = rec;
    rec.start();
  };

  const stopListening = () => {
    recognitionRef.current?.stop();
    setPhase("ready");
  };

  const nextSentence = () => {
    if (idx >= filtered.length - 1) {
      addToast(`🎉 Hoàn thành! Điểm TB: ${Math.round(scores.reduce((a,b)=>a+b,0)/scores.length)}`, "success");
      setIdx(0); setScores([]); setResult(null); setPhase("ready");
      return;
    }
    setIdx(i => i + 1);
    setResult(null);
    setPhase("ready");
  };

  const avgScore = scores.length > 0 ? Math.round(scores.reduce((a,b)=>a+b,0)/scores.length) : null;
  const sent = filtered[idx];

  return (
    <div className="max-w-3xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-rose-500 to-orange-500 rounded-2xl p-6 mb-6 text-white">
        <div className="flex items-center gap-3">
          <span className="text-4xl">🎙️</span>
          <div>
            <h1 className="text-2xl font-extrabold">Shadowing Mode</h1>
            <p className="text-rose-100 text-sm">Nghe → Đọc theo → AI chấm điểm cả câu</p>
          </div>
        </div>
      </div>

      {/* Controls */}
      <div className="bg-white rounded-2xl shadow-sm p-4 mb-4 flex flex-wrap gap-3 items-center">
        <div className="flex flex-wrap gap-1.5 flex-1">
          {topics.slice(0, 6).map(t => (
            <button key={t} onClick={() => { setTopic(t); setIdx(0); setResult(null); setPhase("ready"); }}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${
                topic === t ? "bg-rose-500 text-white" : "bg-gray-100 text-gray-500 hover:bg-rose-50"
              }`}>{t}</button>
          ))}
        </div>
        {avgScore !== null && (
          <div className={`px-3 py-1.5 rounded-full text-sm font-bold ${scoreColor(avgScore)}`}>
            📊 TB: {avgScore}/100
          </div>
        )}
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><div className="w-10 h-10 border-4 border-rose-200 border-t-rose-500 rounded-full animate-spin"/></div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <span className="text-6xl block mb-3">🎙️</span>
          Học thêm từ vựng có câu ví dụ để luyện shadowing!
        </div>
      ) : (
        <div className="space-y-4">
          {/* Progress */}
          <div className="flex items-center gap-3">
            <div className="flex-1 bg-gray-100 rounded-full h-2">
              <div className="bg-rose-500 h-2 rounded-full transition-all" style={{ width: `${((idx+1)/filtered.length)*100}%` }}/>
            </div>
            <span className="text-sm text-gray-500 font-medium">{idx+1}/{filtered.length}</span>
          </div>

          {/* Phase indicator */}
          <div className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium ${
            phase === "playing" ? "bg-indigo-50 text-indigo-600" :
            phase === "listening" ? "bg-rose-50 text-rose-600" :
            phase === "assessing" ? "bg-yellow-50 text-yellow-600" :
            phase === "result" ? "bg-green-50 text-green-600" :
            "bg-gray-50 text-gray-500"
          }`}>
            {phase === "ready" && "👂 Nhấn ▶️ để nghe câu mẫu, sau đó nhấn 🎤 để đọc theo"}
            {phase === "playing" && "🔊 Đang phát... Lắng nghe kỹ!"}
            {phase === "listening" && "🎤 Đọc theo ngay bây giờ!"}
            {phase === "assessing" && "⏳ Meow đang chấm điểm..."}
            {phase === "result" && "✅ Xem kết quả bên dưới"}
          </div>

          {/* Sentence card */}
          <div className={`bg-white rounded-2xl shadow-sm p-6 border-2 transition-all ${
            phase === "listening" ? "border-rose-400" : "border-transparent"
          }`}>
            <div className="flex items-center gap-2 mb-3">
              <span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Câu ví dụ</span>
              <span className="text-xs text-gray-300">· {sent?.word}</span>
            </div>

            {/* Sentence with word highlighting */}
            <p className="text-gray-800 text-lg font-medium leading-relaxed mb-3">
              {result ? (
                // Show word-level coloring
                sent.text.split(" ").map((w, i) => {
                  const clean = w.toLowerCase().replace(/[^a-z]/g, "");
                  const spokenWords = (result.spoken || "").toLowerCase().split(/\s+/).map(s => s.replace(/[^a-z]/g, ""));
                  const correct = spokenWords.includes(clean);
                  return (
                    <span key={i} className={`mr-1 ${correct ? "text-green-600 font-semibold" : "text-red-500"}`}>{w}</span>
                  );
                })
              ) : (
                sent.text
              )}
            </p>

            {sent.translation && (
              <p className="text-gray-400 text-sm italic">{sent.translation}</p>
            )}

            {spokenText && (
              <div className="mt-3 pt-3 border-t border-gray-100">
                <span className="text-xs text-gray-400">🎤 Bạn nói: </span>
                <span className="text-gray-500 text-sm italic">"{spokenText}"</span>
              </div>
            )}
          </div>

          {/* Controls */}
          <div className="flex justify-center gap-4">
            <button onClick={playSentence} disabled={phase === "playing" || phase === "assessing"}
              className="flex flex-col items-center gap-1 disabled:opacity-40">
              <div className="w-16 h-16 bg-indigo-100 text-indigo-600 rounded-full flex items-center justify-center text-2xl hover:bg-indigo-200 transition-colors">
                ▶️
              </div>
              <span className="text-xs text-gray-500">Nghe</span>
            </button>

            <button
              onClick={phase === "listening" ? stopListening : startListening}
              disabled={phase === "playing" || phase === "assessing"}
              className="flex flex-col items-center gap-1 disabled:opacity-40">
              <div className={`w-16 h-16 rounded-full flex items-center justify-center text-2xl transition-all ${
                phase === "listening"
                  ? "bg-rose-500 text-white animate-pulse shadow-lg shadow-rose-300"
                  : "bg-rose-100 text-rose-600 hover:bg-rose-200"
              }`}>
                🎤
              </div>
              <span className="text-xs text-gray-500">{phase === "listening" ? "Dừng" : "Đọc theo"}</span>
            </button>

            <button onClick={nextSentence} disabled={phase !== "result" && phase !== "ready"}
              className="flex flex-col items-center gap-1 disabled:opacity-40">
              <div className="w-16 h-16 bg-green-100 text-green-600 rounded-full flex items-center justify-center text-2xl hover:bg-green-200 transition-colors">
                ⏭️
              </div>
              <span className="text-xs text-gray-500">Tiếp</span>
            </button>
          </div>

          {/* Result */}
          {result && (
            <div className={`rounded-2xl border-2 p-5 ${scoreBg(result.score)}`}>
              <div className="flex items-center gap-4">
                <div className={`text-4xl font-black ${scoreColor(result.score)}`}>{result.score}</div>
                <div className="text-gray-400 text-lg">/100</div>
                <div className="flex-1">
                  <p className="font-semibold text-gray-700">{result.comment}</p>
                  {result.tip && <p className="text-gray-500 text-sm mt-0.5">💡 {result.tip}</p>}
                </div>
              </div>
            </div>
          )}

          {/* Score history */}
          {scores.length > 1 && (
            <div className="bg-white rounded-2xl shadow-sm p-4">
              <p className="text-sm font-semibold text-gray-500 mb-3">📈 Tiến trình</p>
              <div className="flex items-end gap-1.5 h-12">
                {scores.map((s, i) => (
                  <div key={i} className="flex-1 flex flex-col items-center gap-0.5">
                    <div className="w-full rounded-t transition-all"
                      style={{ height: `${(s/100)*40}px`, background: s >= 80 ? "#06D6A0" : s >= 60 ? "#FFB347" : "#FF4757" }}/>
                    {i === scores.length - 1 && <span className="text-xs font-bold text-indigo-600">{s}</span>}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
