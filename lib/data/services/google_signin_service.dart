import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {

  Future<UserCredential> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: '1060637668034-1o87o6qune23elgh52rht5ch4m7dmt1f.apps.googleusercontent.com',
    );

    final googleUser = await GoogleSignIn.instance.authenticate();

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }
}