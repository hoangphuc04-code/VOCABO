/**
 * PlaceholderPage.jsx — Placeholder cho các trang chưa migrate
 * Hiển thị thông báo "đang phát triển" với link đến webapp cũ
 */
export default function PlaceholderPage({ title, emoji }) {
  return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="bg-white rounded-2xl shadow-card p-10 text-center max-w-md">
        <div className="text-6xl mb-4">{emoji}</div>
        <h2 className="text-2xl font-black text-gray-800 mb-2">{title}</h2>
        <p className="text-gray-400 text-sm">
          Trang này đang được chuyển đổi sang React.
        </p>
      </div>
    </div>
  );
}
