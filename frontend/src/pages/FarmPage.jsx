
/**
 * FarmPage.jsx — Nông trại đầy đủ: trồng cây, nuôi động vật, hồ cá, kho, chợ, nhiệm vụ
 */
import { useEffect, useState, useRef } from "react";
import {
  doc, onSnapshot, collection, query, where, orderBy, limit,
  getDocs, setDoc, updateDoc, addDoc, serverTimestamp, getDoc
} from "firebase/firestore";
import { getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

// ─── Static data ──────────────────────────────────────────────────────────────
const CROPS = {
  carrot:     { emoji: "🥕", growHours: 2,  sellPrice: 5,  seedCost: 2,  label: "Cà rốt" },
  tomato:     { emoji: "🍅", growHours: 4,  sellPrice: 8,  seedCost: 3,  label: "Cà chua" },
  corn:       { emoji: "🌽", growHours: 6,  sellPrice: 12, seedCost: 5,  label: "Ngô" },
  strawberry: { emoji: "🍓", growHours: 8,  sellPrice: 15, seedCost: 6,  label: "Dâu" },
  wheat:      { emoji: "🌾", growHours: 1,  sellPrice: 3,  seedCost: 1,  label: "Lúa mì" },
  potato:     { emoji: "🥔", growHours: 3,  sellPrice: 6,  seedCost: 2,  label: "Khoai tây" },
  watermelon: { emoji: "🍉", growHours: 12, sellPrice: 25, seedCost: 10, label: "Dưa hấu" },
  pumpkin:    { emoji: "🎃", growHours: 10, sellPrice: 20, seedCost: 8,  label: "Bí ngô" },
};
const ANIMALS = {
  chicken: { emoji: "🐔", product: "egg",     productEmoji: "🥚", productValue: 8,  productionHours: 4,  feedCost: 3,  label: "Gà" },
  duck:    { emoji: "🦆", product: "feather", productEmoji: "🪶", productValue: 10, productionHours: 6,  feedCost: 4,  label: "Vịt" },
  cow:     { emoji: "🐄", product: "milk",    productEmoji: "🥛", productValue: 15, productionHours: 8,  feedCost: 6,  label: "Bò" },
  pig:     { emoji: "🐷", product: "meat",    productEmoji: "🥩", productValue: 20, productionHours: 12, feedCost: 8,  label: "Lợn" },
};
const FISH = {
  fish:     { emoji: "🐟", growHours: 3, sellPrice: 6,  label: "Cá thường" },
  carp:     { emoji: "🐠", growHours: 5, sellPrice: 10, label: "Cá chép" },
  salmon:   { emoji: "🐡", growHours: 8, sellPrice: 18, label: "Cá hồi" },
  goldfish: { emoji: "🐟", growHours: 2, sellPrice: 4,  label: "Cá vàng" },
};
const TABS = ["🌱 Vườn", "🐄 Chuồng trại", "🐟 Hồ cá", "📦 Kho", "🏪 Chợ", "📋 Nhiệm vụ"];

// ─── Helpers ──────────────────────────────────────────────────────────────────
function getProgress(plantedAt, growHours) {
  if (!plantedAt) return 0;
  const planted = plantedAt?.toDate?.() || new Date(plantedAt);
  const elapsed = (Date.now() - planted.getTime()) / 3600000;
  return Math.min(1, elapsed / growHours);
}
function formatTimeLeft(plantedAt, growHours) {
  if (!plantedAt) return "";
  const planted = plantedAt?.toDate?.() || new Date(plantedAt);
  const elapsed = (Date.now() - planted.getTime()) / 3600000;
  const remaining = growHours - elapsed;
  if (remaining <= 0) return "Sẵn sàng!";
  const h = Math.floor(remaining);
  const m = Math.floor((remaining - h) * 60);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}
function isReady(plantedAt, growHours) {
  if (!plantedAt) return false;
  const planted = plantedAt?.toDate?.() || new Date(plantedAt);
  return (Date.now() - planted.getTime()) / 3600000 >= growHours;
}
