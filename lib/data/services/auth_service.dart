import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_secrets.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// EMAIL LOGIN
  Future<User?> loginWithEmail(
      String email,
      String password,
      ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    }
  }

  /// REGISTER
  Future<User?> registerWithEmail(
      String email,
      String password,
      ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Register failed");
    }
  }

  /// GOOGLE LOGIN
  Future<User?> signInWithGoogle() async {
    try {
      // Initialize with serverClientId from .env
      await GoogleSignIn.instance.initialize(
        serverClientId: AppSecrets.googleServerClientId.isNotEmpty
            ? AppSecrets.googleServerClientId
            : null,
      );

      // Authenticate — returns GoogleSignInAccount
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // Get idToken for Firebase credential
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      debugPrint('Google login failed: $e');
      rethrow;
    }
  }

  /// LOGOUT
  Future<void> logout() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}