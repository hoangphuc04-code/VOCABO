/**
 * VocabMapPage.jsx — Bản đồ từ vựng trực quan (Tính năng 6)
 * Word cloud theo chủ đề, màu theo độ thành thạo
 */
import { useState, useEffect, useRef } from "react";
import { collection, query, where, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const STRENGTH_COLOR = (s) => {
  if (s >= 0.8) return { bg: "#06D6A0", text: "#fff", border: "#04b589" };
  if (s >= 0.5) return { bg: "#FFB347", text: "#fff", border: "#e09a30" };
  return { bg: "#FF4757", text: "#fff", border: "#e03040" };
};

const STRENGTH_LABEL = (s) => {
  if (s >= 0.8) return "Thuộc lòng ⭐";
  if (s >= 0.5) return "Đang học 📖";
  return "Mới học 🌱";
};

export default function VocabMapPage() {
  const { user } = useAppStore(s => ({ user: s.user }));
  const [nodes, setNodes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("Tất cả");
  const [topics, setTopics] = useState(["Tất cả"]);
  const [selected, setSelected] = useState(null);
  const [search, setSearch] = useState("");
  const [view, setView] = useState("cloud"); // cloud | list
  const canvasRef = useRef(null);
  const animRef = useRef(null);
  const timeRef = useRef(0);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    Promise.all([
      getDocs(query(collection(db, "users", user.uid, "learned_words"))),
      getDocs(query(collection(db, "vocabulary_progress"), where("uid", "==", user.uid))),
    ]).then(([learnedSnap, progressSnap]) => {
      const strengthMap = {};
      progressSnap.forEach(d => { strengthMap[d.data().wordId] = d.data().strength || 0.5; });

      const topicSet = new Set(["Tất cả"]);
      const rng = (seed) => { let x = Math.sin(seed) * 10000; return x - Math.floor(x); };

      const ns = learnedSnap.docs.map((d, i) => {
        const data = d.data();
        const strength = strengthMap[data.wordId] || 0.5;
        topicSet.add(data.topicName || "Khác");
        return {
          id: d.id,
          word: data.word || "",
          meaning: data.meaning || "",
          phonetic: data.phonetic || "",
          topic: data.topicName || "Khác",
          topicEmoji: data.topicEmoji || "📚",
          strength,
          x: 0.05 + rng(i * 7.3) * 0.9,
          y: 0.05 + rng(i * 3.7) * 0.9,
          size: 14 + strength * 18,
          floatOffset: rng(i * 1.1) * Math.PI * 2,
        };
      });

      setNodes(ns);
      setTopics([...topicSet]);
      setLoading(false);
    });
  }, [user]);

  // Canvas animation
  useEffect(() => {
    if (view !== "cloud" || !canvasRef.current || nodes.length === 0) return;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");

    const draw = (t) => {
      timeRef.current = t;
      const W = canvas.width, H = canvas.height;
      ctx.clearRect(0, 0, W, H);

      const filtered = nodes.filter(n =>
        (filter === "Tất cả" || n.topic === filter) &&
        (search === "" || n.word.toLowerCase().includes(search.toLowerCase()))
      );

      for (const node of filtered) {
        const x = node.x * W;
        const floatY = Math.sin(t * 0.001 + node.floatOffset) * 4;
        const y = node.y * H + floatY;
        const { bg, border } = STRENGTH_COLOR(node.strength);
        const r = node.size;

        // Glow
        ctx.save();
        ctx.shadowColor = bg;
        ctx.shadowBlur = 12;
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fillStyle = bg + "33";
        ctx.fill();
        ctx.restore();

        // Circle
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fillStyle = bg + "44";
        ctx.fill();
        ctx.strokeStyle = border;
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // Text
        ctx.fillStyle = bg;
        ctx.font = `bold ${Math.max(10, r * 0.55)}px system-ui`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(node.word, x, y);
      }

      animRef.current = requestAnimationFrame(draw);
    };

    animRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(animRef.current);
  }, [nodes, filter, search, view]);

  const handleCanvasClick = (e) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (canvas.height / rect.height);
    const W = canvas.width, H = canvas.height;

    const filtered = nodes.filter(n => filter === "Tất cả" || n.topic === filter);
    for (const node of filtered) {
      const x = node.x * W, y = node.y * H;
      const dist = Math.sqrt((mx - x) ** 2 + (my - y) ** 2);
      if (dist < node.size + 8) {
        setSelected(selected?.id === node.id ? null : node);
        return;
      }
    }
    setSelected(null);
  };

  const filteredNodes = nodes.filter(n =>
    (filter === "Tất cả" || n.topic === filter) &&
    (search === "" || n.word.toLowerCase().includes(search.toLowerCase()) || n.meaning.toLowerCase().includes(search.toLowerCase()))
  );

  const stats = {
    total: nodes.length,
    mastered: nodes.filter(n => n.strength >= 0.8).length,
    learning: nodes.filter(n => n.strength >= 0.5 && n.strength < 0.8).length,
    newWords: nodes.filter(n => n.strength < 0.5).length,
  };

  return (
    <div className="max-w-6xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-emerald-500 to-teal-600 rounded-2xl p-6 mb-6 text-white">
        <div className="flex items-center gap-3 mb-3">
          <span className="text-4xl">🗺️</span>
          <div>
            <h1 className="text-2xl font-extrabold">Bản đồ từ vựng</h1>
            <p className="text-emerald-100 text-sm">Trực quan hóa kho từ vựng của bạn</p>
          </div>
        </div>
        {/* Stats */}
        <div className="grid grid-cols-4 gap-3">
          {[
            { label: "Tổng từ", value: stats.total, emoji: "📚" },
            { label: "Thuộc lòng", value: stats.mastered, emoji: "⭐" },
            { label: "Đang học", value: stats.learning, emoji: "📖" },
            { label: "Mới học", value: stats.newWords, emoji: "🌱" },
          ].map(s => (
            <div key={s.label} className="bg-white/20 rounded-xl p-3 text-center">
              <p className="text-xl">{s.emoji}</p>
              <p className="text-xl font-extrabold">{s.value}</p>
              <p className="text-emerald-100 text-xs">{s.label}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Controls */}
      <div className="bg-white rounded-2xl shadow-sm p-4 mb-4 flex flex-wrap gap-3 items-center">
        {/* Search */}
        <div className="relative flex-1 min-w-48">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">🔍</span>
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Tìm từ vựng..."
            className="w-full pl-9 pr-4 py-2 border border-gray-200 rounded-xl text-sm focus:border-emerald-400 outline-none"/>
        </div>

        {/* Topic filter */}
        <div className="flex flex-wrap gap-1.5">
          {topics.slice(0, 8).map(t => (
            <button key={t} onClick={() => setFilter(t)}
              className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${
                filter === t ? "bg-emerald-600 text-white" : "bg-gray-100 text-gray-500 hover:bg-emerald-50"
              }`}>{t}</button>
          ))}
        </div>

        {/* View toggle */}
        <div className="flex gap-1 bg-gray-100 rounded-xl p-1">
          {[["cloud","☁️"],["list","📋"]].map(([v,e]) => (
            <button key={v} onClick={() => setView(v)}
              className={`px-3 py-1.5 rounded-lg text-sm font-semibold transition-all ${view === v ? "bg-white shadow text-emerald-600" : "text-gray-400"}`}>
              {e}
            </button>
          ))}
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center gap-4 mb-4 px-1">
        <span className="text-gray-400 text-xs">Độ thành thạo:</span>
        {[["#FF4757","Mới học"],["#FFB347","Đang học"],["#06D6A0","Thuộc lòng"]].map(([c,l]) => (
          <div key={l} className="flex items-center gap-1.5">
            <div className="w-3 h-3 rounded-full" style={{ background: c }}/>
            <span className="text-xs text-gray-500">{l}</span>
          </div>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><div className="w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"/></div>
      ) : nodes.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <span className="text-6xl block mb-3">🗺️</span>
          Học thêm từ vựng để xem bản đồ!
        </div>
      ) : view === "cloud" ? (
        <div className="relative bg-gray-900 rounded-2xl overflow-hidden" style={{ height: 500 }}>
          <canvas
            ref={canvasRef}
            width={1200}
            height={500}
            className="w-full h-full cursor-pointer"
            onClick={handleCanvasClick}
          />
          {/* Selected word popup */}
          {selected && (
            <div className="absolute bottom-4 left-4 right-4 md:left-auto md:right-4 md:w-72 bg-gray-800 border border-gray-600 rounded-xl p-4 text-white shadow-xl">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-xl">{selected.topicEmoji}</span>
                <span className="font-extrabold text-lg">{selected.word}</span>
                {selected.phonetic && <span className="text-gray-400 text-sm italic">{selected.phonetic}</span>}
              </div>
              <p className="text-gray-300 text-sm mb-2">{selected.meaning}</p>
              <div className="flex items-center justify-between">
                <span className="text-xs text-gray-400">{selected.topic}</span>
                <span className="text-xs px-2 py-0.5 rounded-full font-semibold"
                  style={{ background: STRENGTH_COLOR(selected.strength).bg + "33", color: STRENGTH_COLOR(selected.strength).bg }}>
                  {STRENGTH_LABEL(selected.strength)}
                </span>
              </div>
            </div>
          )}
        </div>
      ) : (
        /* List view */
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {filteredNodes.map(n => {
            const { bg } = STRENGTH_COLOR(n.strength);
            return (
              <div key={n.id} onClick={() => setSelected(selected?.id === n.id ? null : n)}
                className={`bg-white rounded-xl p-4 cursor-pointer transition-all hover:shadow-md border-2 ${
                  selected?.id === n.id ? "border-emerald-400 shadow-md" : "border-transparent"
                }`}>
                <div className="flex items-center justify-between mb-1">
                  <span className="font-bold text-gray-800">{n.word}</span>
                  <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ background: bg }}/>
                </div>
                <p className="text-gray-400 text-xs">{n.meaning}</p>
                <p className="text-gray-300 text-xs mt-1">{n.topicEmoji} {n.topic}</p>
              </div>
            );
          })}
        </div>
      )}

      {/* Selected detail (list view) */}
      {selected && view === "list" && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 w-full max-w-sm bg-gray-900 text-white rounded-2xl p-4 shadow-2xl border border-gray-700 z-50">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xl">{selected.topicEmoji}</span>
            <span className="font-extrabold text-lg">{selected.word}</span>
            {selected.phonetic && <span className="text-gray-400 text-sm italic">{selected.phonetic}</span>}
          </div>
          <p className="text-gray-300 text-sm">{selected.meaning}</p>
          <div className="flex items-center justify-between mt-2">
            <span className="text-xs text-gray-400">{selected.topic}</span>
            <span className="text-xs px-2 py-0.5 rounded-full font-semibold"
              style={{ background: STRENGTH_COLOR(selected.strength).bg + "33", color: STRENGTH_COLOR(selected.strength).bg }}>
              {STRENGTH_LABEL(selected.strength)}
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
