/**
 * ChatPage.jsx — Tin nhắn realtime với bạn bè
 */
import { useEffect, useState, useRef } from "react";
import {
  collection, query, where, onSnapshot, orderBy, getDocs,
  doc, getDoc, addDoc, updateDoc, serverTimestamp, setDoc
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";
import { Link } from "react-router-dom";

function convId(a, b) { return a < b ? `${a}_${b}` : `${b}_${a}`; }

function formatTime(ts) {
  if (!ts) return "";
  const d = ts?.toDate?.() || new Date(ts);
  const now = new Date();
  if (d.toDateString() === now.toDateString())
    return d.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
  return d.toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit" });
}

export default function ChatPage() {
  const { user } = useAppStore(s => ({ user: s.user }));
  const [conversations, setConversations] = useState([]);
  const [selectedConv, setSelectedConv] = useState(null);
  const [messages, setMessages] = useState([]);
  const [otherUser, setOtherUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [msgInput, setMsgInput] = useState("");
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef(null);

  // Load conversations
  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;

    const q = query(collection(db, "conversations"),
      where("participants", "array-contains", user.uid));

    const unsub = onSnapshot(q, async snap => {
      const list = [];
      for (const d of snap.docs) {
        const data = d.data();
        const participants = data.participants || [];
        const otherUid = participants.find(u => u !== user.uid);
        if (!otherUid) continue;
        const otherDoc = await getDoc(doc(db, "users", otherUid));
        const otherData = otherDoc.data() || {};
        list.push({
          id: d.id, otherUid,
          otherName: otherData.displayName || "Người dùng",
          otherPhoto: otherData.photoURL || "",
          otherLevel: otherData.level || "A1",
          lastMessage: data.lastMessage || "",
          lastMessageAt: data.lastMessageAt,
          unread: data.unread?.[user.uid] || 0,
        });
      }
      list.sort((a, b) => (b.lastMessageAt?.toDate?.() || 0) - (a.lastMessageAt?.toDate?.() || 0));
      setConversations(list);
      setLoading(false);
    });
    return () => unsub();
  }, [user]);

  // Load messages for selected conversation
  useEffect(() => {
    if (!selectedConv || !user) return;
    const db = getFirebaseDb();
    if (!db) return;

    const cid = convId(user.uid, selectedConv.otherUid);
    const q = query(collection(db, "conversations", cid, "messages"),
      orderBy("createdAt", "asc"));

    const unsub = onSnapshot(q, snap => {
      setMessages(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      // Mark as read
      updateDoc(doc(db, "conversations", cid), { [`unread.${user.uid}`]: 0 }).catch(() => {});
    });

    // Load other user info
    getDoc(doc(db, "users", selectedConv.otherUid)).then(d => {
      if (d.exists()) setOtherUser({ uid: selectedConv.otherUid, ...d.data() });
    });

    return () => unsub();
  }, [selectedConv, user]);

  // Scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = async () => {
    if (!msgInput.trim() || !selectedConv || !user || sending) return;
    setSending(true);
    const db = getFirebaseDb();
    if (!db) { setSending(false); return; }

    const cid = convId(user.uid, selectedConv.otherUid);
    const text = msgInput.trim();
    setMsgInput("");

    try {
      await addDoc(collection(db, "conversations", cid, "messages"), {
        senderUid: user.uid, text, type: "text",
        createdAt: serverTimestamp(), readBy: [user.uid],
      });
      await setDoc(doc(db, "conversations", cid), {
        participants: [user.uid, selectedConv.otherUid],
        lastMessage: text, lastMessageAt: serverTimestamp(),
        lastSenderUid: user.uid,
        [`unread.${selectedConv.otherUid}`]: (selectedConv.unread || 0) + 1,
      }, { merge: true });
    } catch (_) {}
    setSending(false);
  };

  return (
    <div className="max-w-5xl mx-auto h-[calc(100vh-120px)] flex gap-4">
      {/* Conversation list */}
      <div className={`${selectedConv ? "hidden md:flex" : "flex"} flex-col w-full md:w-80 bg-white rounded-2xl shadow-sm overflow-hidden flex-shrink-0`}>
        <div className="p-4 border-b border-gray-100">
          <h2 className="font-black text-gray-800">💬 Tin nhắn</h2>
        </div>
        <div className="flex-1 overflow-y-auto">
          {loading ? (
            <div className="p-8 text-center text-gray-400">Đang tải...</div>
          ) : conversations.length === 0 ? (
            <div className="p-8 text-center">
              <div className="text-4xl mb-2">💬</div>
              <p className="text-gray-400 text-sm">Chưa có cuộc trò chuyện nào</p>
              <Link to="/friends" className="text-purple-500 text-sm font-semibold mt-2 block">
                Kết bạn để nhắn tin →
              </Link>
            </div>
          ) : (
            conversations.map(conv => (
              <button key={conv.id} onClick={() => setSelectedConv(conv)}
                className={`w-full flex items-center gap-3 p-4 hover:bg-gray-50 transition-colors text-left border-b border-gray-50
                  ${selectedConv?.id === conv.id ? "bg-purple-50" : ""}`}>
                <div className="w-11 h-11 rounded-full bg-gradient-to-br from-purple-400 to-indigo-400 flex items-center justify-center text-white font-bold flex-shrink-0 overflow-hidden">
                  {conv.otherPhoto ? <img src={conv.otherPhoto} className="w-full h-full object-cover" alt="" /> : conv.otherName?.charAt(0)}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-sm text-gray-800 truncate">{conv.otherName}</span>
                    <span className="text-xs text-gray-400 flex-shrink-0 ml-2">{formatTime(conv.lastMessageAt)}</span>
                  </div>
                  <div className="flex items-center justify-between mt-0.5">
                    <span className="text-xs text-gray-500 truncate">{conv.lastMessage || "Bắt đầu trò chuyện"}</span>
                    {conv.unread > 0 && (
                      <span className="w-5 h-5 bg-purple-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center flex-shrink-0 ml-2">
                        {conv.unread > 9 ? "9+" : conv.unread}
                      </span>
                    )}
                  </div>
                </div>
              </button>
            ))
          )}
        </div>
      </div>

      {/* Chat area */}
      {selectedConv ? (
        <div className="flex-1 flex flex-col bg-white rounded-2xl shadow-sm overflow-hidden">
          {/* Chat header */}
          <div className="p-4 border-b border-gray-100 flex items-center gap-3">
            <button onClick={() => setSelectedConv(null)} className="md:hidden p-1 text-gray-500">←</button>
            <div className="w-9 h-9 rounded-full bg-gradient-to-br from-purple-400 to-indigo-400 flex items-center justify-center text-white font-bold overflow-hidden flex-shrink-0">
              {otherUser?.photoURL ? <img src={otherUser.photoURL} className="w-full h-full object-cover" alt="" /> : selectedConv.otherName?.charAt(0)}
            </div>
            <div>
              <div className="font-bold text-sm text-gray-800">{selectedConv.otherName}</div>
              <div className="text-xs text-gray-400">Cấp độ {selectedConv.otherLevel}</div>
            </div>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto p-4 space-y-3">
            {messages.length === 0 && (
              <div className="text-center text-gray-400 text-sm py-8">
                Bắt đầu cuộc trò chuyện với {selectedConv.otherName} 👋
              </div>
            )}
            {messages.map(msg => {
              const isMe = msg.senderUid === user?.uid;
              const deleted = msg.deletedBy?.includes(user?.uid);
              if (deleted) return null;
              return (
                <div key={msg.id} className={`flex ${isMe ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-[70%] px-4 py-2.5 rounded-2xl text-sm
                    ${isMe ? "bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-br-sm"
                           : "bg-gray-100 text-gray-800 rounded-bl-sm"}`}>
                    <div>{msg.text}</div>
                    <div className={`text-[10px] mt-1 ${isMe ? "text-white/60" : "text-gray-400"}`}>
                      {formatTime(msg.createdAt)}
                    </div>
                  </div>
                </div>
              );
            })}
            <div ref={messagesEndRef} />
          </div>

          {/* Input */}
          <div className="p-3 border-t border-gray-100 flex gap-2">
            <input value={msgInput} onChange={e => setMsgInput(e.target.value)}
              onKeyDown={e => e.key === "Enter" && !e.shiftKey && sendMessage()}
              placeholder="Nhập tin nhắn..."
              className="flex-1 px-4 py-2.5 bg-gray-50 rounded-xl text-sm outline-none focus:bg-white focus:ring-2 focus:ring-purple-200 transition-all" />
            <button onClick={sendMessage} disabled={sending || !msgInput.trim()}
              className="px-4 py-2.5 bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-xl text-sm font-bold disabled:opacity-50 hover:opacity-90 transition-opacity">
              Gửi
            </button>
          </div>
        </div>
      ) : (
        <div className="hidden md:flex flex-1 bg-white rounded-2xl shadow-sm items-center justify-center">
          <div className="text-center text-gray-400">
            <div className="text-5xl mb-3">💬</div>
            <p className="text-sm">Chọn một cuộc trò chuyện để bắt đầu</p>
          </div>
        </div>
      )}
    </div>
  );
}
