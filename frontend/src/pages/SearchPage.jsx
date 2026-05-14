/**
 * SearchPage.jsx — Tra từ điển
 */
import { useState } from "react";
import { lookupWord } from "../lib/api";
import { showToast } from "../store/appStore";

export default function SearchPage() {
  const [query,   setQuery]   = useState("");
  const [lang,    setLang]    = useState("en"); // en = EN→VI, vi = VI→EN
  const [result,  setResult]  = useState(null);
  const [loading, setLoading] = useState(false);
  const [notFound, setNotFound] = useState(false);

  const doSearch = async () => {
    const q = query.trim();
    if (!q) return;
    setLoading(true);
    setResult(null);
    setNotFound(false);
    try {
      // Backend handles translation if needed
      const data = await lookupWord(q);
      setResult(data);
    } catch (e) {
      if (e.message?.includes("not found")) setNotFound(true);
      else showToast("Lỗi kết nối", "error");
    } finally { setLoading(false); }
  };

  const speak = (word) => {
    if (window.speechSynthesis) {
      const utt = new SpeechSynthesisUtterance(word);
      utt.lang = "en-US"; utt.rate = 0.8;
      speechSynthesis.speak(utt);
    }
  };

  return (
    <div>
      {/* Hero */}
      <div className="bg-gradient-primary rounded-2xl p-8 text-white mb-6 text-center">
        <h2 className="text-2xl font-black mb-1">🔍 Tra từ điển</h2>
        <p className="text-sm opacity-75 mb-5">Oxford Dictionary + MyMemory Translation</p>

        {/* Lang toggle */}
        <div className="flex bg-white/20 rounded-xl p-1 gap-1 w-fit mx-auto mb-5">
          {[["en", "🇬🇧 EN → VI"], ["vi", "🇻🇳 VI → EN"]].map(([l, label]) => (
            <button key={l} onClick={() => setLang(l)}
              className={`px-4 py-2 rounded-lg text-sm font-bold transition-all
                ${lang === l ? "bg-white text-primary" : "text-white/80 hover:bg-white/10"}`}>
              {label}
            </button>
          ))}
        </div>

        {/* Search bar */}
        <div className="flex gap-2 max-w-lg mx-auto">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && doSearch()}
            placeholder={lang === "en" ? "Nhập từ tiếng Anh..." : "Nhập từ tiếng Việt..."}
            className="flex-1 px-4 py-3 rounded-xl text-gray-800 text-sm outline-none border-2 border-transparent focus:border-white/50 transition-colors"
          />
          <button onClick={doSearch}
            className="px-5 py-3 bg-white text-primary rounded-xl font-bold text-sm hover:bg-primary-light transition-all">
            Tra từ
          </button>
        </div>
      </div>

      {/* Loading */}
      {loading && (
        <div className="text-center py-12">
          <div className="w-10 h-10 border-4 border-primary-light border-t-primary rounded-full animate-spin mx-auto mb-3" />
          <p className="text-sm text-gray-400">Đang tra từ...</p>
        </div>
      )}

      {/* Not found */}
      {notFound && (
        <div className="bg-white rounded-2xl shadow-card text-center py-12">
          <div className="text-5xl mb-3">🔍</div>
          <h3 className="text-lg font-bold text-gray-700 mb-2">Không tìm thấy "{query}"</h3>
          <p className="text-sm text-gray-400">Thử kiểm tra lại chính tả hoặc đổi ngôn ngữ</p>
        </div>
      )}

      {/* Result */}
      {result && (
        <div className="rounded-2xl overflow-hidden shadow-card">
          {/* Header */}
          <div className="bg-gradient-primary p-6 text-white">
            <div className="flex items-end gap-3 flex-wrap mb-3">
              <span className="text-4xl font-black">{result.word}</span>
              {result.phonetic && <span className="text-lg opacity-75 italic">{result.phonetic}</span>}
              <button onClick={() => speak(result.word)}
                className="px-3 py-1.5 bg-white/20 hover:bg-white/30 rounded-xl text-sm font-semibold transition-all">
                🔊 Phát âm
              </button>
            </div>
            {result.translation && (
              <div className="bg-white/20 rounded-xl px-4 py-2.5 text-sm font-medium">
                🇻🇳 {result.translation}
              </div>
            )}
            <div className="flex gap-2 mt-3 flex-wrap">
              <span className="bg-white/20 rounded-lg px-2.5 py-1 text-xs">Oxford Dictionary</span>
              <span className="bg-white/20 rounded-lg px-2.5 py-1 text-xs">MyMemory</span>
            </div>
          </div>

          {/* Body */}
          <div className="bg-white p-6">
            {result.meanings?.slice(0, 3).map((m, mi) => (
              <div key={mi} className="mb-5">
                <span className="inline-block px-3 py-1 rounded-full bg-primary-light text-primary text-xs font-bold italic mb-3">
                  {m.partOfSpeech}
                </span>
                {m.definitions?.slice(0, 2).map((d, di) => (
                  <div key={di} className="pl-4 border-l-4 border-primary-light mb-3">
                    <span className="font-bold text-primary mr-1">{di + 1}.</span>
                    <span className="text-sm text-gray-700">{d.definition}</span>
                    {d.example && (
                      <div className="text-xs text-gray-400 italic mt-1 pl-4">"{d.example}"</div>
                    )}
                  </div>
                ))}
              </div>
            ))}

            {/* Synonyms / Antonyms */}
            {(() => {
              const syns = new Set(), ants = new Set();
              result.meanings?.forEach((m) => {
                m.synonyms?.slice(0, 4).forEach((s) => syns.add(s));
                m.antonyms?.slice(0, 4).forEach((a) => ants.add(a));
              });
              return (
                <>
                  {syns.size > 0 && (
                    <div className="mb-3">
                      <span className="text-xs font-bold text-gray-400 uppercase tracking-wide mr-2">Synonyms:</span>
                      {[...syns].slice(0, 6).map((s) => (
                        <span key={s} className="inline-block px-2.5 py-1 rounded-full bg-green-50 text-green-700 text-xs font-medium m-0.5">{s}</span>
                      ))}
                    </div>
                  )}
                  {ants.size > 0 && (
                    <div>
                      <span className="text-xs font-bold text-gray-400 uppercase tracking-wide mr-2">Antonyms:</span>
                      {[...ants].slice(0, 6).map((a) => (
                        <span key={a} className="inline-block px-2.5 py-1 rounded-full bg-red-50 text-red-500 text-xs font-medium m-0.5">{a}</span>
                      ))}
                    </div>
                  )}
                </>
              );
            })()}
          </div>
        </div>
      )}
    </div>
  );
}
