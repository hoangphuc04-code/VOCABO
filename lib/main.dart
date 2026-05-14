import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'views/auth/auth_gate.dart';
import 'views/settings/ThemeProvider.dart';
import 'core/config/app_secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Load secrets từ .env (phải trước mọi service khác)
  await AppSecrets.load();

  // ✅ Khởi tạo Firebase (CHỈ 1 LẦN)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider()..loadFromFirestore(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Vocabo",

      // 🌞 Light theme
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF667eea),
        brightness: Brightness.light,
        useMaterial3: true,
      ),

      // 🌙 Dark theme
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF667eea),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),

      // 🎯 Điều khiển theme
      themeMode: themeProvider.themeMode,

      // 🔥 Điều hướng chính
      home: const AuthGate(),

      // (optional)
      routes: AppRoutes.routes,
    );
  }
}