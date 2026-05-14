import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'user_info_screen.dart';
import '../home/home_screen.dart';
import '../admin/admin_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolveScreen(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      // 🔑 Admin check (nếu doc tồn tại)
      if (doc.exists && doc.data()?['role'] == 'admin') {
        return const AdminScreen();
      }

      // ✅ Có profile đầy đủ → HOME
      // Chỉ kiểm tra Firestore — nếu doc chưa có hoặc displayName rỗng
      // thì bắt buộc qua UserInfoScreen dù Google đã có displayName
      final hasProfile = doc.exists &&
          (doc.data()?['displayName'] as String? ?? '').trim().isNotEmpty;

      if (hasProfile) {
        return const HomeScreen();
      }

      // ❌ Chưa có profile trong Firestore → UserInfoScreen (lần đầu)
      return const UserInfoScreen();
    } catch (e) {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ chưa login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        return FutureBuilder<Widget>(
          future: _resolveScreen(user),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return snap.data!;
          },
        );
      },
    );
  }
}