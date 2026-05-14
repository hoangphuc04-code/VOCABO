/**
 * LoadingOverlay.jsx — Full-screen loading spinner
 */
import { useAppStore } from "../store/appStore";

export default function LoadingOverlay() {
  const loading = useAppStore((s) => s.loading);
  if (!loading) return null;

  return (
    <div className="fixed inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center z-[9998]">
      <div className="text-center">
        <div className="w-12 h-12 border-4 border-primary-light border-t-primary rounded-full animate-spin mx-auto mb-3" />
        <p className="text-sm text-gray-500 font-medium">Đang tải...</p>
      </div>
    </div>
  );
}
