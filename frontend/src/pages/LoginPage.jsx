/**
 * LoginPage.jsx — Đăng nhập / Đăng ký
 */
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  sendPasswordResetEmail,
  updateProfile,
} from "firebase/auth";
import { doc, setDoc, getDoc, serverTimestamp } from "firebase/firestore";
import { getFirebaseAuth, getFirebaseDb } from "../lib/firebase";
import { useAppStore, showToast } from "../store/appStore";

const GOOGLE_SVG = (
  <svg width="18" height="18" viewBox="0 0 24 24">
    <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
    <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
    <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
    <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
  </svg>
);

export default function LoginPage() {
  const [tab,      setTab]      = useState("login");
  const [email,    setEmail]    = useState("");
  const [password, setPassword] = useState("");
  const [name,     setName]     = useState("");
  const [showPw,   setShowPw]   = useState(false);
  const [error,    setError]    = useState("");
  const [loading,  setLoading]  = useState(false);

  const config   = useAppStore((s) => s.config);
  const navigate = useNavigate();

  const adminEmails = config?.adminEmails || [];

  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");
    if (!email || !password) { setError("Vui lòng nhập đầy đủ thông tin"); return; }
    setLoading(true);
    try {
      const auth = getFirebaseAuth();
      const cred = await signInWithEmailAndPassword(auth, email, password);
      const db   = getFirebaseDb();
      const snap = await getDoc(doc(db, "users", cred.user.uid));
      const data = snap.exists() ? snap.data() : {};
      navigate(adminEmails.includes(cred.user.email) || data.isAdmin ? "/admin" : "/dashboard");
    } catch (e) {
      const msgs = {
        "auth/user-not-found":    "Email không tồn tại",
        "auth/wrong-password":    "Mật khẩu không đúng",
        "auth/invalid-credential":"Email hoặc mật khẩu không đúng",
        "auth/too-many-requests": "Quá nhiều lần thử. Thử lại sau!",
      };
      setError(msgs[e.code] || "Đăng nhập thất bại");
    } finally { setLoading(false); }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setError("");
    if (!name || !email || !password) { setError("Vui lòng nhập đầy đủ thông tin"); return; }
    if (password.length < 6) { setError("Mật khẩu tối thiểu 6 ký tự"); return; }
    setLoading(true);
    try {
      const auth = getFirebaseAuth();
      const db   = getFirebaseDb();
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(cred.user, { displayName: name });
      await setDoc(doc(db, "users", cred.user.uid), {
        uid: cred.user.uid, displayName: name, email,
        photoURL: "", level: "A1", dailyGoal: 10,
        wordsLearned: 0, streak: 0, progress: 0,
        lastTestScore: 0, totalTests: 0, grammarDone: [],
        createdAt: serverTimestamp(),
      });
      navigate("/dashboard");
    } catch (e) {
      const msgs = {
        "auth/email-already-in-use": "Email đã được sử dụng",
        "auth/invalid-email":        "Email không hợp lệ",
        "auth/weak-password":        "Mật khẩu quá yếu",
      };
      setError(msgs[e.code] || "Đăng ký thất bại");
    } finally { setLoading(false); }
  };

  const handleGoogle = async () => {
    setLoading(true);
    try {
      const auth     = getFirebaseAuth();
      const db       = getFirebaseDb();
      const provider = new GoogleAuthProvider();
      const cred     = await signInWithPopup(auth, provider);
      const snap     = await getDoc(doc(db, "users", cred.user.uid));
      if (!snap.exists()) {
        await setDoc(doc(db, "users", cred.user.uid), {
          uid: cred.user.uid, displayName: cred.user.displayName || "",
          email: cred.user.email, photoURL: cred.user.photoURL || "",
          level: "A1", dailyGoal: 10, wordsLearned: 0,
          streak: 0, progress: 0, lastTestScore: 0,
          totalTests: 0, grammarDone: [], createdAt: serverTimestamp(),
        });
      }
      const data = snap.exists() ? snap.data() : {};
      navigate(adminEmails.includes(cred.user.email) || data.isAdmin ? "/admin" : "/dashboard");
    } catch (e) {
      if (e.code !== "auth/popup-closed-by-user") showToast("Đăng nhập Google thất bại", "error");
    } finally { setLoading(false); }
  };

  const handleForgotPassword = async () => {
    if (!email) { showToast("Nhập email trước nhé!", "warning"); return; }
    try {
      await sendPasswordResetEmail(getFirebaseAuth(), email);
      showToast("Đã gửi email đặt lại mật khẩu!", "success");
    } catch { showToast("Email không tồn tại", "error"); }
  };

  const inputCls = "w-full px-4 py-3 rounded-xl border-2 border-gray-100 text-sm outline-none focus:border-primary transition-colors";
  const labelCls = "block text-xs font-bold text-gray-500 mb-1.5 uppercase tracking-wide";

  return (
    <div className="min-h-screen bg-gradient-primary flex items-center justify-center p-5">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="w-20 h-20 rounded-3xl bg-white/20 backdrop-blur-sm flex items-center justify-center mx-auto mb-4 text-5xl shadow-xl">
            📖
          </div>
          <h1 className="text-4xl font-black text-white mb-1">VOCABO</h1>
          <p className="text-white/70 text-sm">Học tiếng Anh thông minh với Flashcard</p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-3xl p-8 shadow-2xl">
          {/* Tabs */}
          <div className="flex gap-1 bg-gray-100 rounded-2xl p-1 mb-6">
            {["login", "register"].map((t) => (
              <button
                key={t}
                onClick={() => { setTab(t); setError(""); }}
                className={`flex-1 py-2.5 rounded-xl text-sm font-semibold transition-all
                  ${tab === t ? "bg-white text-primary shadow-sm" : "text-gray-500"}`}
              >
                {t === "login" ? "Đăng nhập" : "Đăng ký"}
              </button>
            ))}
          </div>

          {/* Login Form */}
          {tab === "login" && (
            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className={labelCls}>Email</label>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)}
                  placeholder="your@email.com" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Mật khẩu</label>
                <div className="relative">
                  <input type={showPw ? "text" : "password"} value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••" className={`${inputCls} pr-10`} />
                  <button type="button" onClick={() => setShowPw(!showPw)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                    {showPw ? "🙈" : "👁"}
                  </button>
                </div>
                <div className="text-right mt-1.5">
                  <button type="button" onClick={handleForgotPassword}
                    className="text-xs text-primary font-semibold hover:underline">
                    Quên mật khẩu?
                  </button>
                </div>
              </div>
              {error && <p className="text-red-500 text-xs">{error}</p>}
              <button type="submit" disabled={loading}
                className="w-full py-3 rounded-xl bg-gradient-primary text-white font-semibold text-sm disabled:opacity-50 hover:opacity-90 transition-opacity">
                {loading ? "Đang đăng nhập..." : "Đăng nhập"}
              </button>
            </form>
          )}

          {/* Register Form */}
          {tab === "register" && (
            <form onSubmit={handleRegister} className="space-y-4">
              <div>
                <label className={labelCls}>Họ và tên</label>
                <input type="text" value={name} onChange={(e) => setName(e.target.value)}
                  placeholder="Nguyễn Văn A" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Email</label>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)}
                  placeholder="your@email.com" className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Mật khẩu</label>
                <div className="relative">
                  <input type={showPw ? "text" : "password"} value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Tối thiểu 6 ký tự" className={`${inputCls} pr-10`} />
                  <button type="button" onClick={() => setShowPw(!showPw)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                    {showPw ? "🙈" : "👁"}
                  </button>
                </div>
              </div>
              {error && <p className="text-red-500 text-xs">{error}</p>}
              <button type="submit" disabled={loading}
                className="w-full py-3 rounded-xl bg-gradient-primary text-white font-semibold text-sm disabled:opacity-50 hover:opacity-90 transition-opacity">
                {loading ? "Đang tạo tài khoản..." : "Tạo tài khoản"}
              </button>
            </form>
          )}

          {/* Divider */}
          <div className="flex items-center gap-3 my-5">
            <div className="flex-1 h-px bg-gray-100" />
            <span className="text-xs text-gray-400">hoặc</span>
            <div className="flex-1 h-px bg-gray-100" />
          </div>

          {/* Google */}
          <button onClick={handleGoogle} disabled={loading}
            className="w-full py-3 border-2 border-gray-100 rounded-xl text-sm font-semibold flex items-center justify-center gap-2 hover:border-primary hover:bg-primary-light transition-all disabled:opacity-50">
            {GOOGLE_SVG}
            Tiếp tục với Google
          </button>
        </div>

        <p className="text-center text-white/60 text-xs mt-6">© 2024 VOCABO — Học tiếng Anh thông minh</p>
      </div>
    </div>
  );
}
