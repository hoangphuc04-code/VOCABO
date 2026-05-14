/**
 * useAuth.js — Firebase Auth hook
 */
import { useEffect } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { getFirebaseAuth, getFirebaseDb } from "../lib/firebase";
import { useAppStore } from "../store/appStore";

export function useAuth() {
  const { user, userData, authLoading, setUser, setUserData, setAuthLoading } = useAppStore();

  useEffect(() => {
    const auth = getFirebaseAuth();
    if (!auth) return;

    const unsub = onAuthStateChanged(auth, async (firebaseUser) => {
      setUser(firebaseUser);
      if (firebaseUser) {
        try {
          const db   = getFirebaseDb();
          const snap = await getDoc(doc(db, "users", firebaseUser.uid));
          setUserData(snap.exists() ? snap.data() : {});
        } catch {
          setUserData({});
        }
      } else {
        setUserData(null);
      }
      setAuthLoading(false);
    });

    return unsub;
  }, []);

  return { user, userData, authLoading };
}
