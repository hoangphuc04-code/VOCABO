/**
 * WordStoryPage.jsx — Học từ qua câu chuyện AI (Tính năng 4)
 * Chọn từ đã học → Meow AI tạo câu chuyện → nhấn từ highlight để xem nghĩa
 */
import { useState, useEffect } from "react";
import {
  collection, query, where, getDocs, addDoc, serverTimestamp
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const GROQ_KEY = import.meta.env.VITE_GROQ_API_KEY ?? "";

async function generateStory(words) {
  const wordDetails = words.map(w => `- ${w.word} (${w.meaning})`).join("\n");
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${GROQ_KEY}` },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        {
          role: "system",
          content: `Bạn là Meow 😺 — chuyên gia tạo câu chuyện học tiếng Anh.
Tạo câu chuyện ngắn tiếng Anh (5-7 câu) có chứa các từ được yêu cầu.
Trả lời ĐÚNG định dạng JSON:
{"title":"Tiêu đề","story":"Nội dung tiếng Anh...","storyVi":"Bản dịch tiếng Việt..."}
KHÔNG thêm text nào ngoài JSON.`,
        },
        { role: "user", content: `Tạo câu chuyện chứa:\n${wordDetails}` },
      ],
      max_tokens: 600,
      temperature: 0.8,
    }),
  });
  const data = await res.json();
  const reply = data.choices?.[0]?.message?.content || "";
  const s = reply.indexOf("{"), e = reply.lastIndexOf("}");
  if (s !== -1 && e !== -1) return JSON.parse(reply.slice(s, e + 1));
  return null;
}

// Highlight các từ trong câu chuyện
function HighlightedStory({ text, words, onWordClick, selectedWord }) {
  if (!text) return null;
  const parts = [];
  let remaining = text;
  let pos = 0;

  // Build sorted match list
  const matches = [];
  for (const w of words) {
    const re = new RegExp(`\\b${w.word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "gi");
    let m;
    while ((m = re.exec(text)) !== null) {
      matches.push({ start: m.index, end: m.index + m[0].length, word: w, original: m[0] });
    }
  }
  matches.sort((a, b) => a.start - b.start);

  let cursor = 0;
  const spans = [];
  for (const match of matches) {
    if (match.start < cursor) continue;
    if (match.start > cursor) spans.push({ type: "text", content: text.slice(cursor, match.start) });
    spans.push({ type: "word", content: match.original, word: match.word });
    cursor = match.end;
  }
  if (cursor < text.length) spans.push({ type: "text", content: text.slice(cursor) });

  return (
    <p className="text-gray-700 text-base leading-relaxed">
      {spans.map((s, i) =>
        s.type === "text" ? (
          <span key={i}>{s.content}</span>
        ) : (
          <button
            key={i}
            onClick={() => onWordClick(s.word)}
            className={`inline font-bold px-0.5 rounded transition-all cursor-pointer border-b-2 ${
              selectedWord?.word === s.word.word
                ? "bg-indigo-100 text-indigo-700 border-indigo-500"
                : "text-indigo-600 border-indigo-300 hover:bg-indigo-50"
            }`}
          >
            {s.content}
          </button>
        )
      )}
    </p>
  );
}

export default function WordStoryPage() {
  const { user, addToast } = useAppStore(s => ({ user: s.user, addToast: s.addToast }));
  const [allWords, setAllWords] = useState([]);
  const [selected, setSelected] = useState([]);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [story, setStory] = useState(null);
  const [selectedWord, setSelectedWord] = useState(null);
  const [showVi, setShowVi] = useState(false);
  const [savedStories, setSavedStories] = useState([]);
  const [tab, setTab] = useState("create"); // create | history

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    Promise.all([
      getDocs(query(collection(db, "users", user.uid, "learned_words"))),
      getDocs(query(collection(db, "word_stories"), where("uid", "==", user.uid))),
    ]).then(([learnedSnap, storiesSnap]) => {
      setAllWords(learnedSnap.docs.map(d => d.data()).filter(w => w.word));
      setSavedStories(storiesSnap.docs.map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0)));
      setLoading(false);
    });
  }, [user]);

  const toggleWord = (w) => {
    if (selected.find(s => s.word === w.word)) {
      setSelected(selected.filter(s => s.word !== w.word));
    } else if (selected.length < 5) {
      setSelected([...selected, w]);
    } else {
      addToast("Chọn tối đa 5 từ!", "warning");
    }
  };

  const handleGenerate = async () => {
    if (selected.length < 2) { addToast("Chọn ít nhất 2 từ!", "warning"); return; }
    setGenerating(true);
    setStory(null);
    setSelectedWord(null);
    try {
      const result = await generateStory(selected);
      if (result) {
        setStory({ ...result, words: selected });
        // Save to Firestore
        const db = getFirebaseDb();
        await addDoc(collection(db, "word_stories"), {
          uid: user.uid,
          title: result.title,
          story: result.story,
          storyVi: result.storyVi,
          words: selected.map(w => w.word),
          createdAt: serverTimestamp(),
        });
        addToast("✅ Câu chuyện đã được tạo!", "success");
      } else {
        addToast("Không tạo được câu chuyện. Thử lại!", "error");
      }
    } catch (e) {
      addToast("Lỗi kết nối AI", "error");
    }
    setGenerating(false);
  };

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl p-6 mb-6 text-white">
        <div className="flex items-center gap-3 mb-2">
          <span className="text-4xl">📖</span>
          <div>
            <h1 className="text-2xl font-extrabold">Word Story Mode</h1>
            <p className="text-indigo-100 text-sm">Học từ vựng qua câu chuyện AI — nhớ lâu hơn 3x</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[["create","✨ Tạo câu chuyện"],["history","📚 Lịch sử"]].map(([t,l]) => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-5 py-2 rounded-xl font-semibold text-sm transition-all ${
              tab === t ? "bg-indigo-600 text-white shadow" : "bg-white text-gray-500 hover:bg-indigo-50"
            }`}>{l}</button>
        ))}
      </div>

      {tab === "create" ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Word selector */}
          <div className="bg-white rounded-2xl shadow-sm p-5">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-gray-800">Chọn từ ({selected.length}/5)</h2>
              {selected.length >= 2 && (
                <button onClick={handleGenerate} disabled={generating}
                  className="px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-semibold hover:bg-indigo-700 disabled:opacity-50 flex items-center gap-2">
                  {generating ? <><span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"/>Đang tạo...</> : "✨ Tạo chuyện"}
                </button>
              )}
            </div>

            {/* Selected chips */}
            {selected.length > 0 && (
              <div className="flex flex-wrap gap-2 mb-4 p-3 bg-indigo-50 rounded-xl">
                {selected.map(w => (
                  <span key={w.word} onClick={() => toggleWord(w)}
                    className="flex items-center gap-1 px-3 py-1 bg-indigo-600 text-white rounded-full text-xs font-semibold cursor-pointer hover:bg-indigo-700">
                    {w.word} <span>×</span>
                  </span>
                ))}
              </div>
            )}

            {loading ? (
              <div className="flex justify-center py-8"><div className="w-8 h-8 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"/></div>
            ) : allWords.length === 0 ? (
              <p className="text-gray-400 text-center py-8">Học thêm từ vựng để tạo câu chuyện!</p>
            ) : (
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {allWords.slice(0, 50).map(w => {
                  const isSel = selected.find(s => s.word === w.word);
                  return (
                    <button key={w.word} onClick={() => toggleWord(w)}
                      className={`w-full flex items-center gap-3 p-3 rounded-xl text-left transition-all ${
                        isSel ? "bg-indigo-50 border-2 border-indigo-400" : "bg-gray-50 border-2 border-transparent hover:border-indigo-200"
                      }`}>
                      <div className={`w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 ${isSel ? "bg-indigo-600" : "bg-gray-200"}`}>
                        {isSel ? <span className="text-white text-xs">✓</span> : <span className="text-gray-400 text-xs">+</span>}
                      </div>
                      <div>
                        <p className="font-semibold text-gray-800 text-sm">{w.word}</p>
                        <p className="text-gray-400 text-xs">{w.meaning}</p>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Story display */}
          <div className="bg-white rounded-2xl shadow-sm p-5">
            {generating ? (
              <div className="flex flex-col items-center justify-center h-64 gap-4">
                <div className="text-5xl animate-bounce">😺</div>
                <p className="text-indigo-600 font-semibold">Meow đang viết câu chuyện...</p>
                <div className="w-8 h-8 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"/>
              </div>
            ) : story ? (
              <div>
                <div className="flex items-center justify-between mb-4">
                  <h3 className="font-bold text-gray-800 text-lg">{story.title}</h3>
                  <button onClick={() => setShowVi(!showVi)}
                    className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${showVi ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
                    🇻🇳 Dịch
                  </button>
                </div>

                {/* Word chips */}
                <div className="flex flex-wrap gap-1.5 mb-4">
                  {story.words.map(w => (
                    <span key={w.word} className="px-2 py-0.5 bg-indigo-50 text-indigo-600 rounded-full text-xs font-semibold border border-indigo-200">
                      {w.word}
                    </span>
                  ))}
                </div>

                <HighlightedStory
                  text={story.story}
                  words={story.words}
                  onWordClick={setSelectedWord}
                  selectedWord={selectedWord}
                />

                {showVi && (
                  <div className="mt-4 p-3 bg-green-50 rounded-xl border border-green-200">
                    <p className="text-xs font-semibold text-green-700 mb-1">🇻🇳 Bản dịch:</p>
                    <p className="text-gray-600 text-sm leading-relaxed">{story.storyVi}</p>
                  </div>
                )}

                {/* Word popup */}
                {selectedWord && (
                  <div className="mt-4 p-4 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-xl text-white">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-extrabold text-xl">{selectedWord.word}</span>
                      {selectedWord.phonetic && <span className="text-indigo-200 text-sm italic">{selectedWord.phonetic}</span>}
                    </div>
                    <p className="text-indigo-100 font-medium">{selectedWord.meaning}</p>
                    {selectedWord.example && <p className="text-indigo-200 text-sm italic mt-1">"{selectedWord.example}"</p>}
                  </div>
                )}

                <p className="text-gray-400 text-xs mt-3">💡 Nhấn vào từ được highlight để xem nghĩa</p>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center h-64 text-center">
                <span className="text-5xl mb-3">📖</span>
                <p className="text-gray-500 font-medium">Chọn 2-5 từ và nhấn "Tạo chuyện"</p>
                <p className="text-gray-400 text-sm mt-1">Meow AI sẽ tạo câu chuyện chứa các từ bạn chọn</p>
              </div>
            )}
          </div>
        </div>
      ) : (
        /* History tab */
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {savedStories.length === 0 ? (
            <div className="col-span-2 text-center py-16 text-gray-400">
              <span className="text-5xl block mb-3">📚</span>
              Chưa có câu chuyện nào. Tạo câu chuyện đầu tiên!
            </div>
          ) : savedStories.map(s => (
            <div key={s.id} className="bg-white rounded-2xl shadow-sm p-5 hover:shadow-md transition-shadow">
              <h3 className="font-bold text-gray-800 mb-2">{s.title}</h3>
              <div className="flex flex-wrap gap-1 mb-3">
                {(s.words || []).map(w => (
                  <span key={w} className="px-2 py-0.5 bg-indigo-50 text-indigo-600 rounded-full text-xs">{w}</span>
                ))}
              </div>
              <p className="text-gray-500 text-sm line-clamp-3">{s.story}</p>
              <p className="text-gray-300 text-xs mt-2">
                {s.createdAt?.toDate?.()?.toLocaleDateString("vi-VN") || ""}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
