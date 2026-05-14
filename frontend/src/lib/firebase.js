/**
 * firebase.js — Firebase initialization
 * Config được fetch từ backend API (không hardcode)
 */
import { initializeApp } from "firebase/app";
import { getAuth }       from "firebase/auth";
import { getFirestore }  from "firebase/firestore";

let _app  = null;
let _auth = null;
let _db   = null;

/**
 * Khởi tạo Firebase với config từ backend
 * Gọi 1 lần khi app start
 */
export function initFirebase(config) {
  if (_app) return { app: _app, auth: _auth, db: _db };
  _app  = initializeApp(config);
  _auth = getAuth(_app);
  _db   = getFirestore(_app);
  return { app: _app, auth: _auth, db: _db };
}

export const getFirebaseAuth = () => _auth;
export const getFirebaseDb   = () => _db;
