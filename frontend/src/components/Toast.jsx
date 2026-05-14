/**
 * Toast.jsx — Toast notification component
 */
import { useAppStore } from "../store/appStore";

const ICONS = {
  success: "✅",
  error:   "❌",
  info:    "ℹ️",
  warning: "⚠️",
};

export default function Toast() {
  const { toasts, removeToast } = useAppStore();

  return (
    <div className="fixed bottom-6 right-6 z-[9999] flex flex-col gap-2">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={`
            flex items-center gap-2.5 px-5 py-3 rounded-2xl text-white text-sm font-medium
            min-w-[260px] max-w-[380px] shadow-xl animate-slide-in-right
            ${t.type === "success" ? "bg-success" : ""}
            ${t.type === "error"   ? "bg-danger"  : ""}
            ${t.type === "info"    ? "bg-primary" : ""}
            ${t.type === "warning" ? "bg-warning text-gray-800" : ""}
          `}
          onClick={() => removeToast(t.id)}
        >
          <span className="text-lg">{ICONS[t.type] || ICONS.info}</span>
          <span>{t.message}</span>
        </div>
      ))}
    </div>
  );
}
