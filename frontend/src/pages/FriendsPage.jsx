/**
 * FriendsPage.jsx — Kết bạn, tìm kiếm, lời mời — đầy đủ chức năng
 */
import { useEffect, useState } from "react";
import {
  collection, query, where, onSnapshot, getDocs, addDoc,
  doc, getDoc, updateDoc, setDoc, serverTimestamp, deleteDoc
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";
import { Link } from "react-router-dom";

const TABS = ["👥 Bạn bè", "📬 Lời mời", "🔍 Tìm kiếm"];

function fid(a, b) { return a < b ? `${a}_${b}` : `${b}_${a}`; }

export default function FriendsPage() {
  const { user, userData, addToast } = useAppStore(s => ({
    user: s.user, userData: s.userData, addToast: s.addToast
  }));
  const [activeTab, setActiveTab] = useState(0);
  const [friends, setFriends] = useState([]);
  const [requests, setRequests] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [actionLoading, setActionLoading] = useState({});

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;

    const friendsQ = query(collection(db, "friendships"), where("uids", "array-contains", user.uid));
    const unsubFriends = onSnapshot(friendsQ, snap => {
      const list = snap.docs.map(d => {
        const data = d.data();
        const uids = data.uids || [];
        const friendUid = uids.find(u => u !== user.uid) || "";
        const friendData = data[friendUid] || {};
        return { uid: friendUid, friendshipId: d.id, ...friendData };
      }).filter(f => f.uid);
      setFriends(list);
    });

    const reqQ = query(collection(db, "friend_requests"),
      where("toUid", "==", user.uid), where("status", "==", "pending"));
    const unsubReq = onSnapshot(reqQ, snap => {
      setRequests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    });

    return () => { unsubFriends(); unsubReq(); };
  }, [user]);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setSearching(true);
    const db = getFirebaseDb();
    if (!db) { setSearching(false); return; }
    try {
      const q = searchQuery.trim().toLowerCase();
      const snap = await getDocs(query(collection(db, "users"),
        where("searchName", ">=", q), where("searchName", "<=", q + "\uf8ff")));
      const results = snap.docs
        .map(d => ({ uid: d.id, ...d.data() }))
        .filter(u => u.uid !== user?.uid);
      // Check friendship status for each
      const withStatus = await Promise.all(results.map(async u => {
        const friendship = await getDoc(doc(db, "friendships", fid(user.uid, u.uid)));
        if (friendship.exists()) return { ...u, status: "friends" };
        const sentSnap = await getDocs(query(collection(db, "friend_requests"),
          where("fromUid", "==", user.uid), where("toUid", "==", u.uid), where("status", "==", "pending")));
        if (sentSnap.docs.length > 0) return { ...u, status: "sent" };
        return { ...u, status: "none" };
      }));
      setSearchResults(withStatus);
    } catch (e) { console.error(e); }
    setSearching(false);
  };

  const sendRequest = async (toUser) => {
    setActionLoading(p => ({ ...p, [toUser.uid]: true }));
    const db = getFirebaseDb();
    if (!db || !user) { setActionLoading(p => ({ ...p, [toUser.uid]: false })); return; }
    try {
      // Check if they already sent us a request
      const reverseSnap = await getDocs(query(collection(db, "friend_requests"),
        where("fromUid", "==", toUser.uid), where("toUid", "==", user.uid), where("status", "==", "pending")));
      if (reverseSnap.docs.length > 0) {
        await acceptRequest(reverseSnap.docs[0].id, reverseSnap.docs[0].data());
        setSearchResults(r => r.map(u => u.uid === toUser.uid ? { ...u, status: "friends" } : u));
        addToast("Đã chấp nhận lời mời của họ!", "success");
        return;
      }
      await addDoc(collection(db, "friend_requests"), {
        fromUid: user.uid, toUid: toUser.uid, status: "pending",
        fromName: userData?.displayName || user.displayName || "",
        fromPhoto: userData?.photoURL || user.photoURL || "",
        fromLevel: userData?.level || "A1",
        createdAt: serverTimestamp(),
      });
      setSearchResults(r => r.map(u => u.uid === toUser.uid ? { ...u, status: "sent" } : u));
      addToast("Đã gửi lời mời kết bạn!", "success");
    } catch (e) { addToast("Lỗi: " + e.message, "error"); }
    setActionLoading(p => ({ ...p, [toUser.uid]: false }));
  };

  const acceptRequest = async (reqId, reqData) => {
    setActionLoading(p => ({ ...p, [reqId]: true }));
    const db = getFirebaseDb();
    if (!db || !user) return;
    try {
      const data = reqData || requests.find(r => r.id === reqId);
      if (!data) return;
      const fromUid = data.fromUid;
      const toUid = data.toUid || user.uid;

      const [fromDoc, toDoc] = await Promise.all([
        getDoc(doc(db, "users", fromUid)),
        getDoc(doc(db, "users", toUid)),
      ]);
      const fromData = fromDoc.data() || {};
      const toData = toDoc.data() || {};
      const friendshipId = fid(fromUid, toUid);

      await setDoc(doc(db, "friendships", friendshipId), {
        uids: [fromUid, toUid], createdAt: serverTimestamp(),
        [fromUid]: { displayName: fromData.displayName || "", photoURL: fromData.photoURL || "", level: fromData.level || "A1", streak: fromData.streak || 0 },
        [toUid]: { displayName: toData.displayName || "", photoURL: toData.photoURL || "", level: toData.level || "A1", streak: toData.streak || 0 },
      });
      await updateDoc(doc(db, "friend_requests", reqId), { status: "accepted" });
      // Create conversation
      await setDoc(doc(db, "conversations", friendshipId), {
        participants: [fromUid, toUid], lastMessage: "", lastMessageAt: serverTimestamp(),
        lastSenderUid: "", unread: { [fromUid]: 0, [toUid]: 0 }, createdAt: serverTimestamp(),
      }, { merge: true });
      addToast("Đã chấp nhận lời mời!", "success");
    } catch (e) { addToast("Lỗi: " + e.message, "error"); }
    setActionLoading(p => ({ ...p, [reqId]: false }));
  };

  const declineRequest = async (reqId) => {
    const db = getFirebaseDb();
    if (!db) return;
    try {
      await updateDoc(doc(db, "friend_requests", reqId), { status: "declined" });
      addToast("Đã từ chối", "info");
    } catch (e) { addToast("Lỗi: " + e.message, "error"); }
  };

  const unfriend = async (friendshipId, friendUid) => {
    if (!confirm("Hủy kết bạn?")) return;
    const db = getFirebaseDb();
    if (!db) return;
    try {
      await deleteDoc(doc(db, "friendships", friendshipId));
      addToast("Đã hủy kết bạn", "info");
    } catch (e) { addToast("Lỗi: " + e.message, "error"); }
  };

  return (
    <div className="max-w-3xl mx-auto">
      <div className="bg-gradient-to-r from-purple-500 to-indigo-500 rounded-2xl p-6 text-white mb-6">
        <h1 className="text-2xl font-black mb-1">👥 Bạn bè</h1>
        <p className="text-sm opacity-80">Kết nối với người học tiếng Anh</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-white rounded-2xl p-1.5 shadow-sm mb-6">
        {TABS.map((tab, i) => (
          <button key={tab} onClick={() => setActiveTab(i)}
            className={`flex-1 py-2 rounded-xl text-sm font-semibold transition-all relative
              ${activeTab === i ? "bg-gradient-to-r from-purple-500 to-indigo-500 text-white" : "text-gray-500 hover:bg-gray-50"}`}>
            {tab}
            {i === 1 && requests.length > 0 && (
              <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                {requests.length}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Friends Tab */}
      {activeTab === 0 && (
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <h2 className="font-bold text-gray-800 mb-4">Danh sách bạn bè ({friends.length})</h2>
          {friends.length === 0 ? (
            <div className="text-center py-8 text-gray-400">
              <div className="text-4xl mb-2">👥</div>
              <p className="text-sm">Chưa có bạn bè. Hãy tìm kiếm và kết bạn!</p>
            </div>
          ) : (
            <div className="space-y-2">
              {friends.map(friend => (
                <div key={friend.uid} className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 group">
                  <div className="w-11 h-11 rounded-full bg-gradient-to-br from-purple-400 to-indigo-400 flex items-center justify-center text-white font-bold flex-shrink-0 overflow-hidden">
                    {friend.photoURL ? <img src={friend.photoURL} className="w-full h-full rounded-full object-cover" alt="" /> : friend.displayName?.charAt(0) || "?"}
                  </div>
                  <div className="flex-1">
                    <div className="font-semibold text-sm text-gray-800">{friend.displayName || "Người dùng"}</div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-xs bg-purple-50 text-purple-600 px-2 py-0.5 rounded-full font-semibold">{friend.level || "A1"}</span>
                      <span className="text-xs text-gray-400">🔥 {friend.streak || 0} ngày</span>
                    </div>
                  </div>
                  <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Link to="/chat" className="px-3 py-1.5 bg-purple-50 text-purple-600 text-xs font-bold rounded-lg hover:bg-purple-100">
                      💬 Chat
                    </Link>
                    <button onClick={() => unfriend(friend.friendshipId, friend.uid)}
                      className="px-3 py-1.5 bg-red-50 text-red-500 text-xs font-bold rounded-lg hover:bg-red-100">
                      Hủy
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Requests Tab */}
      {activeTab === 1 && (
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <h2 className="font-bold text-gray-800 mb-4">Lời mời kết bạn ({requests.length})</h2>
          {requests.length === 0 ? (
            <div className="text-center py-8 text-gray-400">
              <div className="text-4xl mb-2">📬</div>
              <p className="text-sm">Không có lời mời nào</p>
            </div>
          ) : (
            <div className="space-y-3">
              {requests.map(req => (
                <div key={req.id} className="flex items-center gap-3 p-4 bg-purple-50 rounded-xl border border-purple-100">
                  <div className="w-11 h-11 rounded-full bg-gradient-to-br from-purple-400 to-indigo-400 flex items-center justify-center text-white font-bold flex-shrink-0 overflow-hidden">
                    {req.fromPhoto ? <img src={req.fromPhoto} className="w-full h-full rounded-full object-cover" alt="" /> : req.fromName?.charAt(0) || "?"}
                  </div>
                  <div className="flex-1">
                    <div className="font-semibold text-sm text-gray-800">{req.fromName || "Người dùng"}</div>
                    <div className="text-xs text-gray-500">muốn kết bạn với bạn</div>
                    <span className="text-xs bg-purple-100 text-purple-600 px-2 py-0.5 rounded-full font-semibold">{req.fromLevel || "A1"}</span>
                  </div>
                  <div className="flex gap-2">
                    <button onClick={() => acceptRequest(req.id)}
                      disabled={actionLoading[req.id]}
                      className="w-9 h-9 bg-green-500 text-white rounded-xl flex items-center justify-center hover:bg-green-600 transition-colors disabled:opacity-50">
                      {actionLoading[req.id] ? "..." : "✓"}
                    </button>
                    <button onClick={() => declineRequest(req.id)}
                      className="w-9 h-9 bg-red-100 text-red-500 rounded-xl flex items-center justify-center hover:bg-red-200 transition-colors">
                      ✕
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Search Tab */}
      {activeTab === 2 && (
        <div className="bg-white rounded-2xl shadow-sm p-6">
          <h2 className="font-bold text-gray-800 mb-4">Tìm kiếm bạn bè</h2>
          <div className="flex gap-2 mb-4">
            <input type="text" value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onKeyDown={e => e.key === "Enter" && handleSearch()}
              placeholder="Nhập tên hoặc email..."
              className="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:border-purple-400" />
            <button onClick={handleSearch} disabled={searching}
              className="px-4 py-2.5 bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-xl text-sm font-semibold hover:opacity-90 disabled:opacity-50">
              {searching ? "..." : "Tìm"}
            </button>
          </div>
          {searchResults.length === 0 && searchQuery && !searching ? (
            <div className="text-center py-6 text-gray-400"><p className="text-sm">Không tìm thấy kết quả</p></div>
          ) : (
            <div className="space-y-3">
              {searchResults.map(u => (
                <div key={u.uid} className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 border border-gray-100">
                  <div className="w-11 h-11 rounded-full bg-gradient-to-br from-purple-400 to-indigo-400 flex items-center justify-center text-white font-bold flex-shrink-0 overflow-hidden">
                    {u.photoURL ? <img src={u.photoURL} className="w-full h-full rounded-full object-cover" alt="" /> : u.displayName?.charAt(0) || "?"}
                  </div>
                  <div className="flex-1">
                    <div className="font-semibold text-sm text-gray-800">{u.displayName || "Người dùng"}</div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-xs bg-purple-50 text-purple-600 px-2 py-0.5 rounded-full font-semibold">{u.level || "A1"}</span>
                      <span className="text-xs text-gray-400">🔥 {u.streak || 0}</span>
                    </div>
                  </div>
                  {u.status === "friends" ? (
                    <span className="px-3 py-1.5 bg-green-50 text-green-600 text-xs font-bold rounded-lg">✓ Bạn bè</span>
                  ) : u.status === "sent" ? (
                    <span className="px-3 py-1.5 bg-gray-100 text-gray-500 text-xs font-bold rounded-lg">Đã gửi</span>
                  ) : (
                    <button onClick={() => sendRequest(u)} disabled={actionLoading[u.uid]}
                      className="px-3 py-1.5 bg-gradient-to-r from-purple-500 to-indigo-500 text-white text-xs font-bold rounded-lg hover:opacity-90 disabled:opacity-50">
                      {actionLoading[u.uid] ? "..." : "+ Kết bạn"}
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
