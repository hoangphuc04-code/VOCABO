/**
 * AIConversationPage.jsx — AI Conversation Partner (Tính năng 8)
 * Meow AI đóng vai người bản ngữ, sửa lỗi ngữ pháp inline
 */
import { useState, useRef, useEffect } from "react";
import { addDoc, collection, serverTimestamp } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const GROQ_KEY = import.meta.env.VITE_GROQ_API_KEY ?? "";

const SCENARIOS = [
  { id: "freeChat",      emoji: "💬", label: "Free Chat",          desc: "Nói chuyện tự do về bất kỳ chủ đề nào",
    opening: "Hey! I'm your English conversation partner. What would you like to talk about today? 😊",
    role: "You are a friendly American friend. Chat naturally about any topic." },
  { id: "restaurant",   emoji: "🍽️", label: "Tại nhà hàng",       desc: "Gọi món, hỏi về menu, thanh toán",
    opening: "Welcome! Table for how many? Can I start you off with something to drink?",
    role: "You are a waiter at an American restaurant. The user is a customer." },
  { id: "jobInterview", emoji: "💼", label: "Phỏng vấn xin việc", desc: "Trả lời câu hỏi phỏng vấn bằng tiếng Anh",
    opening: "Good morning! Please have a seat. Tell me a little about yourself and why you're interested in this position.",
    role: "You are a recruiter interviewing the user for a Software Engineer position." },
  { id: "shopping",     emoji: "🛍️", label: "Mua sắm",            desc: "Hỏi giá, size, màu sắc, trả giá",
    opening: "Hi there! Welcome to our store. Are you looking for anything in particular today?",
    role: "You are a sales associate at a fashion store. The user wants to buy clothes." },
  { id: "travel",       emoji: "✈️", label: "Du lịch / Sân bay",  desc: "Check-in, hỏi đường, đặt phòng",
    opening: "Good afternoon! Welcome to the check-in counter. May I see your passport and booking confirmation, please?",
    role: "You are an airport staff member helping the user with their flight." },
];

const SYSTEM_PROMPT = (scenario) => `${scenario.role}

RULES:
1. ALWAYS respond in English naturally (as a native speaker would)
2. Keep responses conversational, 2-4 sentences max
3. After your response, if the user made grammar mistakes, add:
[CORRECTION]
- Original: "user's sentence"
- Better: "corrected version"
- Why: brief explanation in Vietnamese
[/CORRECTION]
4. If English is perfect, do NOT add [CORRECTION]
5. Occasionally suggest better vocabulary: 💡 Better: "word" instead of "word"`;

function parseCorrection(text) {
  const s = text.indexOf("[CORRECTION]"), e = text.indexOf("[/CORRECTION]");
  if (s === -1 || e === -1) return null;
  const block = text.slice(s + 12, e).trim();
  const lines = block.split("\n").map(l => l.trim());
  let original = "", better = "", why = "";
  for (const l of lines) {
    if (l.startsWith("- Original:")) original = l.replace("- Original:", "").trim().replace(/"/g, "");
    if (l.startsWith("- Better:")) better = l.replace("- Better:", "").trim().replace(/"/g, "");
    if (l.startsWith("- Why:")) why = l.replace("- Why:", "").trim();
  }
  return better ? { original, better, why } : null;
}

function removeCorrection(text) {
  return text.replace(/\[CORRECTION\][\s\S]*?\[\/CORRECTION\]/g, "").trim();
}

export default function AIConversationPage() {
  const { user, userData, addToast } = useAppStore(s => ({ user: s.user, userData: s.userData, addToast: s.addToast }));
  const [scenario, setScenario] = useState(null);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState({ turns: 0, corrections: 0 });
  const scrollRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages, loading]);

  const startScenario = (s) => {
    setScenario(s);
    setMessages([{ isUser: false, text: s.opening, correction: null }]);
    setStats({ turns: 0, corrections: 0 });
    setTimeout(() => inputRef.current?.focus(), 100);
  };

  const send = async () => {
    if (!input.trim() || loading || !scenario) return;
    const text = input.trim();
    setInput("");
    setMessages(m => [...m, { isUser: true, text, correction: null }]);
    setLoading(true);

    try {
      const history = messages.slice(-16).map(m => ({
        role: m.isUser ? "user" : "assistant",
        content: m.text,
      }));

      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${GROQ_KEY}` },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [
            { role: "system", content: SYSTEM_PROMPT(scenario) },
            ...history,
            { role: "user", content: text },
          ],
          max_tokens: 400,
          temperature: 0.75,
        }),
      });
      const data = await res.json();
      const reply = data.choices?.[0]?.message?.content || "";
      const correction = parseCorrection(reply);
      const cleanReply = removeCorrection(reply);

      setMessages(m => {
        const updated = [...m];
        if (correction) {
          updated[updated.length - 1] = { ...updated[updated.length - 1], correction };
        }
        return [...updated, { isUser: false, text: cleanReply, correction: null }];
      });
      setStats(s => ({ turns: s.turns + 1, corrections: s.corrections + (correction ? 1 : 0) }));

      // Save session
      const db = getFirebaseDb();
      if (db && user) {
        await addDoc(collection(db, "conversation_sessions"), {
          uid: user.uid,
          scenario: scenario.id,
          messageCount: messages.length + 2,
          createdAt: serverTimestamp(),
        }).catch(() => {});
      }
    } catch (e) {
      addToast("Lỗi kết nối AI", "error");
    }
    setLoading(false);
  };

  if (!scenario) {
    return (
      <div className="max-w-3xl mx-auto">
        <div className="bg-gradient-to-r from-violet-500 to-purple-600 rounded-2xl p-6 mb-6 text-white">
          <div className="flex items-center gap-3">
            <span className="text-4xl">🤖</span>
            <div>
              <h1 className="text-2xl font-extrabold">AI Conversation Partner</h1>
              <p className="text-violet-100 text-sm">Luyện nói tiếng Anh với AI — sửa lỗi ngữ pháp tức thì</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-2xl shadow-sm p-5 mb-4">
          <div className="flex items-start gap-3 p-4 bg-violet-50 rounded-xl">
            <span className="text-2xl">💡</span>
            <div>
              <p className="font-semibold text-violet-800 text-sm">Cách hoạt động</p>
              <p className="text-violet-600 text-sm mt-1">AI đóng vai người bản ngữ, bạn chat bằng tiếng Anh. Nếu có lỗi ngữ pháp, AI sẽ gợi ý sửa ngay bên dưới tin nhắn của bạn.</p>
            </div>
          </div>
        </div>

        <h2 className="font-bold text-gray-700 mb-3">Chọn kịch bản:</h2>
        <div className="space-y-3">
          {SCENARIOS.map(s => (
            <button key={s.id} onClick={() => startScenario(s)}
              className="w-full flex items-center gap-4 p-4 bg-white rounded-2xl shadow-sm hover:shadow-md border-2 border-transparent hover:border-violet-300 transition-all text-left">
              <span className="text-3xl">{s.emoji}</span>
              <div className="flex-1">
                <p className="font-bold text-gray-800">{s.label}</p>
                <p className="text-gray-400 text-sm">{s.desc}</p>
              </div>
              <span className="text-gray-300">→</span>
            </button>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto flex flex-col" style={{ height: "calc(100vh - 120px)" }}>
      {/* Header */}
      <div className="bg-white rounded-2xl shadow-sm p-4 mb-3 flex items-center gap-3">
        <button onClick={() => setScenario(null)} className="p-2 hover:bg-gray-100 rounded-xl transition-colors">
          ←
        </button>
        <span className="text-2xl">{scenario.emoji}</span>
        <div className="flex-1">
          <p className="font-bold text-gray-800">{scenario.label}</p>
          <p className="text-gray-400 text-xs">{stats.turns} lượt · {stats.corrections} lỗi đã sửa</p>
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse"/>
          <span className="text-xs text-gray-400">Online</span>
        </div>
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto space-y-3 px-1 pb-3">
        {messages.map((msg, i) => (
          <div key={i} className={`flex ${msg.isUser ? "justify-end" : "justify-start"} gap-2`}>
            {!msg.isUser && (
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center text-white text-sm flex-shrink-0 mt-1">
                🤖
              </div>
            )}
            <div className={`max-w-[75%] ${msg.isUser ? "items-end" : "items-start"} flex flex-col gap-1.5`}>
              <div className={`px-4 py-3 rounded-2xl text-sm leading-relaxed ${
                msg.isUser
                  ? "bg-violet-600 text-white rounded-br-sm"
                  : "bg-white shadow-sm text-gray-800 rounded-bl-sm"
              }`}>
                {msg.text}
              </div>
              {/* Grammar correction */}
              {msg.correction && (
                <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 text-xs w-full">
                  <p className="font-bold text-amber-700 mb-1.5">✏️ Gợi ý sửa ngữ pháp:</p>
                  <p className="text-red-500 line-through mb-0.5">❌ {msg.correction.original}</p>
                  <p className="text-green-600 font-semibold mb-0.5">✅ {msg.correction.better}</p>
                  {msg.correction.why && <p className="text-gray-500">💡 {msg.correction.why}</p>}
                </div>
              )}
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex gap-2">
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center text-white text-sm flex-shrink-0">🤖</div>
            <div className="bg-white shadow-sm rounded-2xl rounded-bl-sm px-4 py-3 flex gap-1.5 items-center">
              {[0,1,2].map(i => (
                <div key={i} className="w-2 h-2 bg-gray-300 rounded-full animate-bounce" style={{ animationDelay: `${i*150}ms` }}/>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <div className="bg-white rounded-2xl shadow-sm p-3 flex gap-2">
        <input
          ref={inputRef}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === "Enter" && !e.shiftKey && send()}
          disabled={loading}
          placeholder="Type in English..."
          className="flex-1 px-4 py-2.5 bg-gray-50 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-300 disabled:opacity-50"
        />
        <button onClick={send} disabled={loading || !input.trim()}
          className="w-10 h-10 bg-violet-600 text-white rounded-xl flex items-center justify-center hover:bg-violet-700 disabled:opacity-40 transition-all flex-shrink-0">
          {loading
            ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"/>
            : <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/></svg>
          }
        </button>
      </div>
    </div>
  );
}
