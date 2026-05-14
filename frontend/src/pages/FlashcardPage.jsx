/**
 * FlashcardPage.jsx — Học từ vựng theo chủ đề
 * - Tab "Chủ đề có sẵn": 8 preset topics, tự động seed từ vựng qua API
 * - Tab "Của tôi": tạo/xóa topic tùy chỉnh
 * - Màn học: lật thẻ, đánh giá biết/không biết, tiến độ
 */
import { useEffect, useState, useRef } from "react";
import {
  collection, query, where, getDocs, addDoc, deleteDoc,
  doc, updateDoc, serverTimestamp, getDoc, setDoc
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

// ─── Preset Topics ────────────────────────────────────────────────────────────
const PRESET_TOPICS = [
  { name: "Animals",    nameVi: "Động vật",  emoji: "🐾", color: "#FF6B6B",
    words: ["elephant","lion","tiger","dolphin","eagle","rabbit","wolf","giraffe","penguin","crocodile","butterfly","octopus","kangaroo","cheetah","gorilla","flamingo","panda","koala","jaguar","hawk"] },
  { name: "Food",       nameVi: "Đồ ăn",     emoji: "🍎", color: "#FF9F1C",
    words: ["apple","banana","mango","strawberry","avocado","broccoli","salmon","noodle","rice","cheese","chocolate","mushroom","pineapple","coconut","almond","blueberry","cucumber","tomato","watermelon","lemon"] },
  { name: "Travel",     nameVi: "Du lịch",   emoji: "✈️", color: "#3A86FF",
    words: ["passport","luggage","airport","hotel","tourism","adventure","destination","journey","ticket","reservation","landmark","souvenir","itinerary","explore","culture","museum","beach","mountain","cruise","backpack"] },
  { name: "Technology", nameVi: "Công nghệ", emoji: "💻", color: "#8338EC",
    words: ["algorithm","database","network","software","hardware","cybersecurity","artificial","interface","bandwidth","processor","wireless","browser","download","encryption","firewall","server","protocol","digital","innovation","automation"] },
  { name: "Business",   nameVi: "Kinh doanh",emoji: "💼", color: "#06D6A0",
    words: ["investment","revenue","profit","strategy","marketing","entrepreneur","contract","negotiation","dividend","budget","shareholder","merger","bankruptcy","franchise","commodity","inflation","interest","assets","liability","capital"] },
  { name: "Health",     nameVi: "Sức khoẻ",  emoji: "❤️", color: "#FF006E",
    words: ["medicine","symptom","diagnosis","therapy","nutrition","exercise","vitamin","antibody","immune","vaccine","surgeon","pharmacy","mental","anxiety","depression","recovery","prevention","hygiene","cardiovascular","metabolism"] },
  { name: "Nature",     nameVi: "Thiên nhiên",emoji: "🌿", color: "#2EC4B6",
    words: ["forest","ocean","desert","volcano","glacier","ecosystem","biodiversity","atmosphere","hurricane","earthquake","waterfall","coral","drought","erosion","habitat","fossil","mineral","rainfall","climate","lightning"] },
  { name: "Education",  nameVi: "Giáo dục",  emoji: "🎓", color: "#FFBE0B",
    words: ["knowledge","scholarship","curriculum","academic","research","examination","diploma","graduate","lecture","laboratory","thesis","semester","tuition","discipline","textbook","assignment","concept","theory","skill","certificate"] },
];

// ─── Fetch word data from free APIs ──────────────────────────────────────────
async function fetchWordData(word) {
  let phonetic = "", example = "", defEn = "";
  try {
    const res = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${word}`);
    if (res.ok) {
      const data = await res.json();
      if (data[0]) {
        phonetic = data[0].phonetic || data[0].phonetics?.find(p => p.text)?.text || "";
        for (const m of data[0].meanings || []) {
          for (const d of m.definitions || []) {
            if (d.definition) { defEn = d.definition; example = d.example || ""; break; }
          }
          if (defEn) break;
        }
      }
    }
  } catch (_) {}

  let meaningVi = word;
  try {
    const r = await fetch(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(word)}&langpair=en|vi`);
    if (r.ok) {
      const j = await r.json();
      meaningVi = j.responseData?.translatedText || word;
    }
  } catch (_) {}

  return { word, meaning: meaningVi, phonetic, example, exampleVi: "", imageUrl: "" };
}

// ─── Learn Screen ─────────────────────────────────────────────────────────────
function LearnScreen({ topic, words, onBack }) {
  const { user, userData, setUserData, addToast } = useAppStore(s => ({
    user: s.user, userData: s.userData, setUserData: s.setUserData, addToast: s.addToast
  }));
  const [idx, setIdx] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [known, setKnown] = useState([]);
  const [unknown, setUnknown] = useState([]);
  const [done, setDone] = useState(false);

  const card = words[idx];

  const handleKnow = async (knows) => {
    if (knows) setKnown(p => [...p, card]);
    else setUnknown(p => [...p, card]);
    setFlipped(false);
    if (idx + 1 >= words.length) {
      setDone(true);
      // Save study session
      try {
        const db = getFirebaseDb();
        if (db && user) {
          await addDoc(collection(db, "study_sessions"), {
            uid: user.uid, wordsLearned: known.length + (knows ? 1 : 0),
            date: serverTimestamp(), duration: 5, topic: topic.name,
          });
          const newCount = (userData?.wordsLearned || 0) + known.length + (knows ? 1 : 0);
          await updateDoc(doc(db, "users", user.uid), { wordsLearned: newCount });
          setUserData({ ...userData, wordsLearned: newCount });
        }
      } catch (_) {}
      addToast(`Hoàn thành! Biết ${known.length + (knows ? 1 : 0)}/${words.length} từ 🎉`, "success");
    } else {
      setTimeout(() => setIdx(i => i + 1), 200);
    }
  };

  if (done) {
    const knownCount = known.length;
    const pct = Math.round((knownCount / words.length) * 100);
    return (
      <div className="max-w-lg mx-auto text-center py-10">
        <div className="text-6xl mb-4">🎉</div>
        <h2 className="text-2xl font-black text-gray-800 mb-2">Hoàn thành!</h2>
        <p className="text-gray-500 mb-6">Bạn biết {knownCount}/{words.length} từ ({pct}%)</p>
        <div className="grid grid-cols-2 gap-4 mb-8">
          <div className="bg-green-50 rounded-2xl p-5">
            <div className="text-3xl font-black text-green-600">{knownCount}</div>
            <div className="text-sm text-green-700">✅ Đã biết</div>
          </div>
          <div className="bg-red-50 rounded-2xl p-5">
            <div className="text-3xl font-black text-red-500">{unknown.length}</div>
            <div className="text-sm text-red-600">❌ Chưa biết</div>
          </div>
        </div>
        <div className="flex gap-3 justify-center">
          {unknown.length > 0 && (
            <button onClick={() => { setIdx(0); setKnown([]); setUnknown([]); setDone(false); }}
              className="px-5 py-2.5 bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-xl font-bold text-sm">
              Học lại từ chưa biết
            </button>
          )}
          <button onClick={onBack}
            className="px-5 py-2.5 border border-gray-200 text-gray-600 rounded-xl font-bold text-sm">
            Quay lại
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-lg mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <button onClick={onBack} className="p-2 rounded-xl hover:bg-gray-100 text-gray-500">←</button>
        <div className="flex-1">
          <div className="text-sm font-bold text-gray-700">{topic.emoji} {topic.nameVi}</div>
          <div className="text-xs text-gray-400">{idx + 1} / {words.length}</div>
        </div>
      </div>

      {/* Progress */}
      <div className="w-full bg-gray-100 rounded-full h-2 mb-6">
        <div className="bg-gradient-to-r from-purple-500 to-indigo-500 h-2 rounded-full transition-all"
          style={{ width: `${((idx) / words.length) * 100}%` }} />
      </div>

      {/* Card */}
      <div className="perspective-1000 mb-6 cursor-pointer" onClick={() => setFlipped(f => !f)}
        style={{ perspective: "1000px" }}>
        <div style={{
          transition: "transform 0.5s",
          transformStyle: "preserve-3d",
          transform: flipped ? "rotateY(180deg)" : "rotateY(0deg)",
          position: "relative", height: "240px"
        }}>
          {/* Front */}
          <div style={{ backfaceVisibility: "hidden", position: "absolute", inset: 0 }}
            className="bg-white rounded-3xl shadow-lg flex flex-col items-center justify-center p-8">
            <div className="text-4xl font-black text-gray-800 mb-3">{card?.word}</div>
            {card?.phonetic && <div className="text-gray-400 text-lg mb-2">{card.phonetic}</div>}
            <div className="text-sm text-gray-400 mt-4">Nhấn để xem nghĩa</div>
          </div>
          {/* Back */}
          <div style={{ backfaceVisibility: "hidden", transform: "rotateY(180deg)", position: "absolute", inset: 0 }}
            className="bg-gradient-to-br from-purple-500 to-indigo-500 rounded-3xl shadow-lg flex flex-col items-center justify-center p-8 text-white">
            <div className="text-3xl font-black mb-3">{card?.meaning}</div>
            {card?.example && (
              <div className="text-sm opacity-80 text-center italic">"{card.example}"</div>
            )}
          </div>
        </div>
      </div>

      {/* Buttons */}
      <div className="flex gap-4">
        <button onClick={() => handleKnow(false)}
          className="flex-1 py-4 bg-red-50 text-red-500 rounded-2xl font-bold text-lg hover:bg-red-100 transition-colors">
          ❌ Chưa biết
        </button>
        <button onClick={() => handleKnow(true)}
          className="flex-1 py-4 bg-green-50 text-green-600 rounded-2xl font-bold text-lg hover:bg-green-100 transition-colors">
          ✅ Đã biết
        </button>
      </div>
    </div>
  );
}

// ─── Main FlashcardPage ───────────────────────────────────────────────────────
export default function FlashcardPage() {
  const { user, addToast } = useAppStore(s => ({ user: s.user, addToast: s.addToast }));
  const [activeTab, setActiveTab] = useState(0);
  const [myTopics, setMyTopics] = useState([]);
  const [loadingTopic, setLoadingTopic] = useState(null);
  const [learningTopic, setLearningTopic] = useState(null);
  const [learningWords, setLearningWords] = useState([]);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newTopicName, setNewTopicName] = useState("");
  const [newTopicEmoji, setNewTopicEmoji] = useState("📚");
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    if (!user) return;
    loadMyTopics();
  }, [user]);

  const loadMyTopics = async () => {
    const db = getFirebaseDb();
    if (!db || !user) return;
    const snap = await getDocs(query(collection(db, "topics"),
      where("uid", "==", user.uid), where("isPreset", "==", false)));
    setMyTopics(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  };

  const openPreset = async (preset) => {
    setLoadingTopic(preset.name);
    const db = getFirebaseDb();
    if (!db || !user) { setLoadingTopic(null); return; }

    try {
      // Check if topic already exists
      const existing = await getDocs(query(collection(db, "topics"),
        where("uid", "==", user.uid), where("name", "==", preset.name), where("isPreset", "==", true)));

      let topicId;
      if (existing.docs.length > 0) {
        topicId = existing.docs[0].id;
        // Check words
        const wordsSnap = await getDocs(collection(db, "topics", topicId, "words"));
        if (wordsSnap.docs.length > 0) {
          const words = wordsSnap.docs.map(d => d.data());
          setLearningTopic({ id: topicId, ...preset });
          setLearningWords(words);
          setLoadingTopic(null);
          return;
        }
      } else {
        // Create topic
        const ref = await addDoc(collection(db, "topics"), {
          uid: user.uid, name: preset.name, nameVi: preset.nameVi,
          emoji: preset.emoji, color: preset.color, wordCount: 0,
          isPreset: true, createdAt: serverTimestamp(),
        });
        topicId = ref.id;
      }

      // Seed words in batches
      addToast("Đang tải từ vựng... ⏳", "info");
      const wordsRef = collection(db, "topics", topicId, "words");
      const batchSize = 5;
      const seededWords = [];
      for (let i = 0; i < preset.words.length; i += batchSize) {
        const batch = preset.words.slice(i, i + batchSize);
        const results = await Promise.all(batch.map(w => fetchWordData(w)));
        for (const wd of results) {
          await addDoc(wordsRef, { ...wd, createdAt: serverTimestamp() });
          seededWords.push(wd);
        }
      }
      await updateDoc(doc(db, "topics", topicId), { wordCount: seededWords.length });
      setLearningTopic({ id: topicId, ...preset });
      setLearningWords(seededWords);
    } catch (e) {
      addToast("Lỗi tải từ vựng: " + e.message, "error");
    } finally {
      setLoadingTopic(null);
    }
  };

  const openMyTopic = async (topic) => {
    setLoadingTopic(topic.id);
    const db = getFirebaseDb();
    if (!db) { setLoadingTopic(null); return; }
    try {
      const snap = await getDocs(collection(db, "topics", topic.id, "words"));
      const words = snap.docs.map(d => d.data());
      if (words.length === 0) { addToast("Chủ đề này chưa có từ nào!", "warning"); setLoadingTopic(null); return; }
      setLearningTopic(topic);
      setLearningWords(words);
    } catch (e) {
      addToast("Lỗi: " + e.message, "error");
    } finally {
      setLoadingTopic(null);
    }
  };

  const createTopic = async () => {
    if (!newTopicName.trim()) return;
    setCreating(true);
    const db = getFirebaseDb();
    if (!db || !user) { setCreating(false); return; }
    try {
      await addDoc(collection(db, "topics"), {
        uid: user.uid, name: newTopicName.trim(), nameVi: newTopicName.trim(),
        emoji: newTopicEmoji, color: "#667eea", wordCount: 0,
        isPreset: false, createdAt: serverTimestamp(),
      });
      addToast("Đã tạo chủ đề!", "success");
      setShowAddModal(false);
      setNewTopicName("");
      loadMyTopics();
    } catch (e) {
      addToast("Lỗi: " + e.message, "error");
    } finally {
      setCreating(false);
    }
  };

  const deleteTopic = async (topicId) => {
    if (!confirm("Xóa chủ đề này?")) return;
    const db = getFirebaseDb();
    if (!db) return;
    try {
      const wordsSnap = await getDocs(collection(db, "topics", topicId, "words"));
      for (const w of wordsSnap.docs) await deleteDoc(w.ref);
      await deleteDoc(doc(db, "topics", topicId));
      addToast("Đã xóa!", "success");
      loadMyTopics();
    } catch (e) {
      addToast("Lỗi: " + e.message, "error");
    }
  };

  if (learningTopic) {
    return <LearnScreen topic={learningTopic} words={learningWords}
      onBack={() => { setLearningTopic(null); setLearningWords([]); }} />;
  }

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-500 to-indigo-500 rounded-2xl p-6 text-white mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-black mb-1">📚 Học từ vựng</h1>
          <p className="text-sm opacity-80">Học theo chủ đề với flashcard</p>
        </div>
        <button onClick={() => setShowAddModal(true)}
          className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center text-xl hover:bg-white/30 transition-colors">
          +
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-white rounded-2xl p-1.5 shadow-sm mb-6">
        {["📖 Chủ đề có sẵn", "🗂️ Của tôi"].map((tab, i) => (
          <button key={tab} onClick={() => setActiveTab(i)}
            className={`flex-1 py-2 rounded-xl text-sm font-semibold transition-all
              ${activeTab === i ? "bg-gradient-to-r from-purple-500 to-indigo-500 text-white" : "text-gray-500 hover:bg-gray-50"}`}>
            {tab}
          </button>
        ))}
      </div>

      {/* Preset Topics */}
      {activeTab === 0 && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {PRESET_TOPICS.map(preset => (
            <button key={preset.name} onClick={() => openPreset(preset)}
              disabled={loadingTopic === preset.name}
              className="relative rounded-2xl p-5 text-left text-white overflow-hidden hover:-translate-y-1 transition-transform disabled:opacity-70"
              style={{ background: `linear-gradient(135deg, ${preset.color}dd, ${preset.color}88)` }}>
              <div className="absolute top-3 right-3 bg-white/20 rounded-lg px-2 py-0.5 text-xs font-semibold">
                {preset.words.length} từ
              </div>
              <div className="text-4xl mb-3">{preset.emoji}</div>
              <div className="font-bold text-base">{preset.name}</div>
              <div className="text-sm opacity-80">{preset.nameVi}</div>
              {loadingTopic === preset.name && (
                <div className="absolute inset-0 bg-black/30 flex items-center justify-center rounded-2xl">
                  <div className="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin" />
                </div>
              )}
            </button>
          ))}
        </div>
      )}

      {/* My Topics */}
      {activeTab === 1 && (
        <div>
          {myTopics.length === 0 ? (
            <div className="bg-white rounded-2xl shadow-sm p-12 text-center">
              <div className="text-5xl mb-3">📚</div>
              <p className="text-gray-500 mb-4">Chưa có chủ đề nào</p>
              <button onClick={() => setShowAddModal(true)}
                className="px-5 py-2.5 bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-xl font-bold text-sm">
                + Tạo chủ đề
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {myTopics.map(topic => (
                <div key={topic.id} className="relative group">
                  <button onClick={() => openMyTopic(topic)}
                    disabled={loadingTopic === topic.id}
                    className="w-full rounded-2xl p-5 text-left text-white overflow-hidden hover:-translate-y-1 transition-transform"
                    style={{ background: `linear-gradient(135deg, ${topic.color || "#667eea"}dd, ${topic.color || "#667eea"}88)` }}>
                    <div className="text-4xl mb-3">{topic.emoji || "📚"}</div>
                    <div className="font-bold text-base truncate">{topic.name}</div>
                    <div className="text-sm opacity-80">{topic.wordCount || 0} từ</div>
                    {loadingTopic === topic.id && (
                      <div className="absolute inset-0 bg-black/30 flex items-center justify-center rounded-2xl">
                        <div className="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      </div>
                    )}
                  </button>
                  <button onClick={() => deleteTopic(topic.id)}
                    className="absolute top-2 right-2 w-7 h-7 bg-red-500 text-white rounded-lg text-xs opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    ✕
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Add Topic Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-6 w-full max-w-sm">
            <h3 className="font-bold text-gray-800 mb-4">➕ Tạo chủ đề mới</h3>
            <div className="mb-3">
              <label className="text-xs font-bold text-gray-500 mb-1 block">Emoji</label>
              <input value={newTopicEmoji} onChange={e => setNewTopicEmoji(e.target.value)}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm outline-none focus:border-purple-400"
                placeholder="📚" maxLength={2} />
            </div>
            <div className="mb-5">
              <label className="text-xs font-bold text-gray-500 mb-1 block">Tên chủ đề</label>
              <input value={newTopicName} onChange={e => setNewTopicName(e.target.value)}
                onKeyDown={e => e.key === "Enter" && createTopic()}
                className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm outline-none focus:border-purple-400"
                placeholder="Ví dụ: IELTS Vocabulary..." />
            </div>
            <div className="flex gap-2">
              <button onClick={createTopic} disabled={creating || !newTopicName.trim()}
                className="flex-1 py-2.5 bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-xl font-bold text-sm disabled:opacity-50">
                {creating ? "Đang tạo..." : "Tạo"}
              </button>
              <button onClick={() => setShowAddModal(false)}
                className="flex-1 py-2.5 border border-gray-200 text-gray-600 rounded-xl font-bold text-sm">
                Hủy
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
