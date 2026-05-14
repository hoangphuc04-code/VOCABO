/**
 * CalendarPage.jsx — Lịch học, hiển thị study sessions
 */
import { useEffect, useState } from "react";
import { collection, query, where, getDocs } from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

const WEEKDAYS = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"];
const MONTHS = [
  "Tháng 1", "Tháng 2", "Tháng 3", "Tháng 4",
  "Tháng 5", "Tháng 6", "Tháng 7", "Tháng 8",
  "Tháng 9", "Tháng 10", "Tháng 11", "Tháng 12",
];

export default function CalendarPage() {
  const { user, userData } = useAppStore((s) => ({ user: s.user, userData: s.userData }));
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [viewDate, setViewDate] = useState(new Date());
  const [selectedDay, setSelectedDay] = useState(null);

  const year = viewDate.getFullYear();
  const month = viewDate.getMonth();

  useEffect(() => {
    if (!user) return;
    const db = getFirebaseDb();
    if (!db) return;
    setLoading(true);
    getDocs(query(collection(db, "study_sessions"), where("uid", "==", user.uid)))
      .then((snap) => {
        setSessions(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [user]);

  // Build a map: "YYYY-MM-DD" -> session data
  const sessionMap = {};
  sessions.forEach((s) => {
    const date = s.date?.toDate?.();
    if (!date) return;
    const key = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
    if (!sessionMap[key]) sessionMap[key] = [];
    sessionMap[key].push(s);
  });

  // Calendar grid
  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const today = new Date();

  const cells = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);

  const getKey = (d) => `${year}-${month}-${d}`;

  // Streak calculation
  const streak = userData?.streak || 0;
  const totalSessions = sessions.length;
  const totalWords = sessions.reduce((acc, s) => acc + (s.wordsLearned || 0), 0);

  const prevMonth = () =>
    setViewDate(new Date(year, month - 1, 1));
  const nextMonth = () =>
    setViewDate(new Date(year, month + 1, 1));

  const selectedSessions = selectedDay ? sessionMap[getKey(selectedDay)] || [] : [];

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-black text-gray-800">📅 Lịch học</h1>
        <p className="text-gray-500 text-sm mt-1">Theo dõi tiến trình học tập của bạn</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white rounded-2xl shadow-card p-5 text-center">
          <div className="text-3xl font-black text-orange-500">🔥 {streak}</div>
          <div className="text-xs text-gray-500 mt-1">Streak ngày</div>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 text-center">
          <div className="text-3xl font-black text-primary">{totalSessions}</div>
          <div className="text-xs text-gray-500 mt-1">Buổi học</div>
        </div>
        <div className="bg-white rounded-2xl shadow-card p-5 text-center">
          <div className="text-3xl font-black text-green-600">{totalWords}</div>
          <div className="text-xs text-gray-500 mt-1">Từ đã học</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Calendar */}
        <div className="lg:col-span-2 bg-white rounded-2xl shadow-card p-6">
          {/* Month navigation */}
          <div className="flex items-center justify-between mb-5">
            <button
              onClick={prevMonth}
              className="p-2 rounded-xl hover:bg-gray-100 text-gray-500"
            >
              ←
            </button>
            <h2 className="font-bold text-gray-800">
              {MONTHS[month]} {year}
            </h2>
            <button
              onClick={nextMonth}
              className="p-2 rounded-xl hover:bg-gray-100 text-gray-500"
            >
              →
            </button>
          </div>

          {/* Weekday headers */}
          <div className="grid grid-cols-7 mb-2">
            {WEEKDAYS.map((d) => (
              <div
                key={d}
                className="text-center text-xs font-bold text-gray-400 py-1"
              >
                {d}
              </div>
            ))}
          </div>

          {/* Days grid */}
          <div className="grid grid-cols-7 gap-1">
            {cells.map((day, i) => {
              if (!day) return <div key={`empty-${i}`} />;
              const key = getKey(day);
              const hasSessions = !!sessionMap[key];
              const isToday =
                today.getDate() === day &&
                today.getMonth() === month &&
                today.getFullYear() === year;
              const isSelected = selectedDay === day;
              const wordsToday = hasSessions
                ? sessionMap[key].reduce((a, s) => a + (s.wordsLearned || 0), 0)
                : 0;

              return (
                <button
                  key={day}
                  onClick={() => setSelectedDay(isSelected ? null : day)}
                  className={`relative aspect-square flex flex-col items-center justify-center rounded-xl text-sm font-medium transition-all
                    ${isSelected ? "bg-primary text-white" : ""}
                    ${isToday && !isSelected ? "border-2 border-primary text-primary font-bold" : ""}
                    ${hasSessions && !isSelected ? "bg-green-50 text-green-700" : ""}
                    ${!hasSessions && !isToday && !isSelected ? "text-gray-600 hover:bg-gray-50" : ""}
                  `}
                >
                  {day}
                  {hasSessions && (
                    <div
                      className={`w-1.5 h-1.5 rounded-full mt-0.5 ${
                        isSelected ? "bg-white" : "bg-green-500"
                      }`}
                    />
                  )}
                </button>
              );
            })}
          </div>

          {/* Legend */}
          <div className="flex items-center gap-4 mt-4 text-xs text-gray-400">
            <span className="flex items-center gap-1">
              <span className="w-3 h-3 rounded bg-green-100 border border-green-300" />
              Đã học
            </span>
            <span className="flex items-center gap-1">
              <span className="w-3 h-3 rounded border-2 border-primary" />
              Hôm nay
            </span>
          </div>
        </div>

        {/* Session detail */}
        <div className="bg-white rounded-2xl shadow-card p-6">
          <h3 className="font-bold text-gray-700 mb-4">
            {selectedDay
              ? `📋 Ngày ${selectedDay}/${month + 1}/${year}`
              : "📋 Chi tiết buổi học"}
          </h3>

          {!selectedDay ? (
            <p className="text-gray-400 text-sm text-center py-8">
              Chọn một ngày để xem chi tiết
            </p>
          ) : selectedSessions.length === 0 ? (
            <div className="text-center py-8">
              <div className="text-4xl mb-2">😴</div>
              <p className="text-gray-400 text-sm">Không có buổi học nào</p>
            </div>
          ) : (
            <div className="space-y-3">
              {selectedSessions.map((s, i) => (
                <div key={i} className="p-4 bg-gray-50 rounded-xl">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-bold text-primary bg-primary-light px-2 py-0.5 rounded-full">
                      Buổi {i + 1}
                    </span>
                    <span className="text-xs text-gray-400">
                      {s.date?.toDate?.()?.toLocaleTimeString("vi-VN", {
                        hour: "2-digit",
                        minute: "2-digit",
                      }) || ""}
                    </span>
                  </div>
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div>
                      <span className="text-gray-400">Từ học:</span>
                      <span className="font-bold text-gray-700 ml-1">
                        {s.wordsLearned || 0}
                      </span>
                    </div>
                    <div>
                      <span className="text-gray-400">Thời gian:</span>
                      <span className="font-bold text-gray-700 ml-1">
                        {s.duration ? `${s.duration}p` : "—"}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
