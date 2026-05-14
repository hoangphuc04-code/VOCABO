/**
 * appStore.js — Global state với Zustand
 * Quản lý: config, auth user, app-wide state
 */
import { create } from "zustand";

export const useAppStore = create((set, get) => ({
  // ── Config từ backend ──────────────────────────────────────────────────────
  config:        null,
  configLoaded:  false,
  setConfig: (config) => set({ config, configLoaded: true }),

  // ── Auth ───────────────────────────────────────────────────────────────────
  user:          null,   // Firebase Auth user
  userData:      null,   // Firestore user document
  authLoading:   true,
  setUser:     (user)     => set({ user }),
  setUserData: (userData) => set({ userData }),
  setAuthLoading: (v)     => set({ authLoading: v }),

  // ── Toast notifications ────────────────────────────────────────────────────
  toasts: [],
  addToast: (message, type = "info", duration = 3500) => {
    const id = Date.now();
    set((s) => ({ toasts: [...s.toasts, { id, message, type }] }));
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
    }, duration);
  },
  removeToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

  // ── Loading overlay ────────────────────────────────────────────────────────
  loading: false,
  setLoading: (v) => set({ loading: v }),
}));

// Convenience helpers
export const showToast   = (msg, type, dur) => useAppStore.getState().addToast(msg, type, dur);
export const showLoading = ()  => useAppStore.getState().setLoading(true);
export const hideLoading = ()  => useAppStore.getState().setLoading(false);
