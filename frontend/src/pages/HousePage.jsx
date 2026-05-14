/**
 * HousePage.jsx — Mini House + Farm overview
 */
import { useEffect, useState } from "react";
import { doc, onSnapshot, collection, query, where, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";
import { Link } from "react-router-dom";

const WALL_COLORS = {
  wall_white:  "#F5F0E8", wall_pink: "#FCE4EC", wall_blue: "#E3F2FD",
  wall_wood:   "#EFEBE9", wall_brick: "#EFEBE9", wall_floral: "#F3E5F5",
  wall_stars:  "#1A1A2E",
};
const FLOOR_COLORS = {
  floor_tile_blue: ["#B3D9F2", "#90CAE8"],
  floor_wood:      ["#D4A574", "#C49060"],
  floor_marble:    ["#F5F5F5", "#E0E0E0"],
  floor_carpet:    ["#EF9A9A", "#E57373"],
  floor_grass:     ["#A5D6A7", "#81C784"],
};

const HOUSE_ITEMS_CATALOGUE = {
  bed_basic: "🛏️", bed_fancy: "🛏️", sofa: "🛋️", table_coffee: "🪑",
  bookshelf: "📚", desk: "🖥️", wardrobe: "🚪", tv: "📺", piano: "🎹",
  plant_small: "🌱", plant_big: "🌿", lamp: "💡", painting: "🖼️",
  globe: "🌍", clock: "🕐", rug: "⭕", fairy_lights: "✨", radio: "📻", flowers: "💐",
};

export default function HousePage() {
  const { user, userData } = useAppStore((s) => ({ user: s.user, userData: s.userData }));
  const [house, setHouse] = useState(null);
  const [farm, setFarm] = useState(null);
  const [visitors, setVisitors] = useState([]);

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;

    const unsubHouse = onSnapshot(doc(db, "houses", user.uid), (snap) => {
      if (snap.exists()) setHouse(snap.data());
    });

    const unsubFarm = onSnapshot(doc(db, "farms", user.uid), (snap) => {
      if (snap.exists()) setFarm(snap.data());
    });

    return () => { unsubHouse(); unsubFarm(); };
  }, [user]);

  const wallColor = WALL_COLORS[house?.wallpaper] || "#F5F0E8";
  const floorColors = FLOOR_COLORS[house?.floorType] || ["#B3D9F2", "#90CAE8"];
  const pet = house?.pet || { type: "cat", name: "Mèo con", hunger: 70, happiness: 80, level: 1 };
  const petEmoji = { cat: "🐱", dog: "🐶", rabbit: "🐰", hamster: "🐹" }[pet.type] || "🐱";

  const placedItems = house?.placedItems || [];
  const coins = userData?.coins || 0;

  // Farm stats
  const plots = farm?.plots || [];
  const animals = farm?.animals || [];
  const fishPond = farm?.fishPond || [];
  const warehouse = farm?.warehouse || {};

  const readyCrops = plots.filter((p) => {
    if (!p.plantedAt || !p.cropType) return false;
    const growTimes = { carrot: 2, tomato: 4, corn: 6, strawberry: 8, wheat: 1, potato: 3, watermelon: 12, pumpkin: 10 };
    const hours = growTimes[p.cropType] || 4;
    const planted = p.plantedAt?.toDate?.() || new Date(p.plantedAt);
    return (Date.now() - planted.getTime()) >= hours * 3600000;
  }).length;

  const warehouseTotal = Object.values(warehouse).reduce((a, b) => a + b, 0);

  return (
    <div className="max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-black text-gray-800">🏡 Mini House</h1>
          <p className="text-sm text-gray-500">Trang trí nhà và quản lý nông trại</p>
        </div>
        <div className="flex items-center gap-2">
          <span className="flex items-center gap-1 bg-yellow-50 border border-yellow-200 px-3 py-1.5 rounded-full text-sm font-bold text-yellow-700">
            🪙 {coins}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Room Preview */}
        <div className="lg:col-span-2">
          <div className="bg-white rounded-2xl shadow-card overflow-hidden">
            <div className="flex items-center justify-between p-4 border-b border-gray-100">
              <h2 className="font-bold text-gray-800">🏠 Phòng của tôi</h2>
              <div className="flex gap-2">
                <span className="text-xs bg-gray-100 px-2 py-1 rounded-lg text-gray-500">
                  {placedItems.length} vật phẩm
                </span>
              </div>
            </div>

            {/* Room canvas */}
            <div
              className="relative overflow-hidden"
              style={{ background: wallColor, minHeight: 280 }}
            >
              {/* Floor grid */}
              <div
                className="absolute inset-0 grid"
                style={{
                  gridTemplateColumns: "repeat(8, 1fr)",
                  gridTemplateRows: "repeat(6, 1fr)",
                }}
              >
                {Array.from({ length: 48 }).map((_, i) => {
                  const row = Math.floor(i / 8);
                  const col = i % 8;
                  const isEven = (row + col) % 2 === 0;
                  return (
                    <div
                      key={i}
                      style={{ background: isEven ? floorColors[0] : floorColors[1] }}
                    />
                  );
                })}
              </div>

              {/* Placed items */}
              {placedItems.slice(0, 12).map((item, i) => {
                const emoji = HOUSE_ITEMS_CATALOGUE[item.itemId] || "📦";
                const left = `${(item.gridX / 8) * 100}%`;
                const top = `${(item.gridY / 6) * 100}%`;
                return (
                  <div
                    key={item.instanceId || i}
                    className="absolute text-2xl"
                    style={{ left, top, transform: `rotate(${item.rotation || 0}deg)` }}
                  >
                    {emoji}
                  </div>
                );
              })}

              {/* Character */}
              <div className="absolute text-2xl" style={{ left: "45%", top: "55%" }}>
                👧
              </div>

              {/* Pet */}
              <div className="absolute" style={{ left: "25%", top: "35%" }}>
                <div className="text-2xl animate-bounce">{petEmoji}</div>
                <div className="text-xs bg-white/90 rounded-lg px-1 text-center">
                  {pet.happiness >= 80 ? "😸" : pet.happiness >= 50 ? "😺" : "😿"}
                </div>
              </div>
            </div>

            {/* Pet stats */}
            <div className="p-4 bg-amber-50 border-t border-amber-100">
              <div className="flex items-center gap-3">
                <span className="text-2xl">{petEmoji}</span>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-1">
                    <span className="font-semibold text-sm text-gray-800">{pet.name}</span>
                    <span className="text-xs text-gray-500">Lv.{pet.level}</span>
                  </div>
                  <div className="flex gap-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-1 mb-0.5">
                        <span className="text-xs">🍖</span>
                        <span className="text-xs text-gray-500">No bụng</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-1.5">
                        <div className="bg-orange-400 h-1.5 rounded-full" style={{ width: `${pet.hunger}%` }} />
                      </div>
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-1 mb-0.5">
                        <span className="text-xs">💕</span>
                        <span className="text-xs text-gray-500">Hạnh phúc</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-1.5">
                        <div className="bg-pink-400 h-1.5 rounded-full" style={{ width: `${pet.happiness}%` }} />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right panel */}
        <div className="flex flex-col gap-4">
          {/* Owned items */}
          <div className="bg-white rounded-2xl shadow-card p-4">
            <h3 className="font-bold text-gray-800 mb-3">🛒 Vật phẩm đã có</h3>
            <div className="flex flex-wrap gap-2">
              {(house?.ownedItems || ["wall_white", "floor_tile_blue", "bed_basic"]).map((id) => {
                const emoji = HOUSE_ITEMS_CATALOGUE[id] || "🎨";
                return (
                  <span key={id} className="text-xl bg-gray-50 rounded-xl p-2" title={id}>
                    {emoji}
                  </span>
                );
              })}
            </div>
          </div>

          {/* Visitors */}
          <div className="bg-white rounded-2xl shadow-card p-4">
            <h3 className="font-bold text-gray-800 mb-3">👥 Khách thăm</h3>
            {(house?.visitors || []).length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-2">Chưa có khách thăm</p>
            ) : (
              <div className="space-y-2">
                {house.visitors.slice(0, 5).map((v, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-full bg-primary-light flex items-center justify-center text-xs font-bold text-primary">
                      {v.name?.charAt(0) || "?"}
                    </div>
                    <span className="text-sm text-gray-700">{v.name}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Farm quick stats */}
          <Link to="/farm" className="bg-gradient-to-br from-green-400 to-teal-500 rounded-2xl p-4 text-white no-underline hover:opacity-90 transition-opacity">
            <h3 className="font-bold mb-3">🌿 Nông trại</h3>
            <div className="grid grid-cols-2 gap-2">
              {[
                { icon: "🌱", label: "Ô đất", value: farm?.unlockedPlots || 6 },
                { icon: "✅", label: "Sẵn thu", value: readyCrops },
                { icon: "🐄", label: "Động vật", value: animals.length },
                { icon: "📦", label: "Kho", value: warehouseTotal },
              ].map(({ icon, label, value }) => (
                <div key={label} className="bg-white/20 rounded-xl p-2 text-center">
                  <div className="text-lg">{icon}</div>
                  <div className="font-bold text-sm">{value}</div>
                  <div className="text-xs opacity-80">{label}</div>
                </div>
              ))}
            </div>
            <div className="mt-3 text-center text-sm font-semibold opacity-90">
              Vào nông trại →
            </div>
          </Link>
        </div>
      </div>

      {/* Shop preview */}
      <div className="mt-6 bg-white rounded-2xl shadow-card p-6">
        <h2 className="font-bold text-gray-800 mb-4">🛒 Cửa hàng trang trí</h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
          {[
            { emoji: "🌸", name: "Tường hồng", price: 50, cat: "Tường" },
            { emoji: "🛋️", name: "Ghế sofa", price: 120, cat: "Nội thất" },
            { emoji: "📚", name: "Kệ sách", price: 100, cat: "Nội thất" },
            { emoji: "✨", name: "Đèn dây", price: 100, cat: "Trang trí" },
            { emoji: "🎹", name: "Đàn piano", price: 300, cat: "Nội thất" },
          ].map((item) => (
            <div key={item.name} className="border border-gray-100 rounded-xl p-3 text-center hover:border-primary hover:bg-primary-light transition-all cursor-pointer">
              <div className="text-3xl mb-2">{item.emoji}</div>
              <div className="text-xs font-semibold text-gray-700">{item.name}</div>
              <div className="text-xs text-gray-400 mb-2">{item.cat}</div>
              <div className="flex items-center justify-center gap-1 text-xs font-bold text-yellow-600">
                🪙 {item.price}
              </div>
            </div>
          ))}
        </div>
        <p className="text-center text-xs text-gray-400 mt-3">
          Mở app Flutter để mua và trang trí nhà đầy đủ
        </p>
      </div>
    </div>
  );
}
