import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn.instance;

  static bool _initialized = false;




  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _google.initialize();
    _initialized = true;
  }


  static Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  static Future<UserCredential> signInWithGoogle() async {
    await _ensureInitialized();

    GoogleSignInAccount? account;
    if (_google.supportsAuthenticate()) {
      account = await _google.authenticate();
    } else {
      account = await _google.attemptLightweightAuthentication();
      if (account == null) {
        throw Exception('No cached Google session. Use authenticate() flow.');
      }
    }

    final auth = account.authentication; // v7: has idToken
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken, // accessToken not required for Firebase
    );
    return await _auth.signInWithCredential(credential);
  }

  static Future<void> logOut() async {
    await _google.signOut();
    await _auth.signOut();
  }





  static User? get currentUser => _auth.currentUser;
}
