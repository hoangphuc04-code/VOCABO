import { useState } from "react";

export default function MeowChat() {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([
    { role: "assistant", content: "Xin chào! Tôi là Meow AI 🐱 Tôi có thể giúp bạn học tiếng Anh!" },
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);

  const send = async () => {
    if (!input.trim() || loading) return;
    const userMsg = input.trim();
    setInput("");
    setMessages((prev) => [...prev, { role: "user", content: userMsg }]);
    setLoading(true);
    try {
      await new Promise((r) => setTimeout(r, 800));
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: `Bạn hỏi: "${userMsg}". Tính năng AI đang được phát triển! 🐱`,
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed bottom-6 right-6 z-50">
      {open && (
        <div className="mb-3 w-80 bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden">
          <div className="bg-gradient-to-r from-purple-500 to-indigo-500 p-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-2xl">🐱</span>
              <div>
                <div className="font-bold text-white text-sm">Meow AI</div>
                <div className="text-white/70 text-xs">Trợ lý học tiếng Anh</div>
              </div>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="text-white/80 hover:text-white text-xl leading-none"
            >
              ×
            </button>
          </div>
          <div className="h-64 overflow-y-auto p-4 space-y-3">
            {messages.map((m, i) => (
              <div
                key={i}
                className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}
              >
                <div
                  className={`max-w-[80%] px-3 py-2 rounded-xl text-sm ${
                    m.role === "user"
                      ? "bg-primary text-white"
                      : "bg-gray-100 text-gray-800"
                  }`}
                >
                  {m.content}
                </div>
              </div>
            ))}
            {loading && (
              <div className="flex justify-start">
                <div className="bg-gray-100 px-3 py-2 rounded-xl text-sm text-gray-500">
                  Đang trả lời...
                </div>
              </div>
            )}
          </div>
          <div className="p-3 border-t border-gray-100 flex gap-2">
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
              placeholder="Nhập câu hỏi..."
              className="flex-1 px-3 py-2 rounded-xl border border-gray-200 text-sm outline-none focus:border-primary"
            />
            <button
              onClick={send}
              disabled={loading}
              className="px-3 py-2 bg-primary text-white rounded-xl text-sm font-semibold disabled:opacity-50"
            >
              Gửi
            </button>
          </div>
        </div>
      )}
      <button
        onClick={() => setOpen(!open)}
        className="w-14 h-14 bg-gradient-to-br from-purple-500 to-indigo-500 rounded-full shadow-lg flex items-center justify-center text-2xl hover:scale-110 transition-transform"
      >
        🐱
      </button>
    </div>
  );
}
