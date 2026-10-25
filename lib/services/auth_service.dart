import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when the user backs out of a native sign-in sheet.
///
/// Callers should swallow this silently — a cancel is not an error.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

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

  /// A cryptographically secure random string, used as the raw nonce for
  /// Sign in with Apple. Apple receives only its SHA256 hash; Firebase is
  /// given the raw value and checks the two match.
  static String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Runs the native Sign in with Apple flow and signs the user into Firebase.
  ///
  /// Throws [SignInCancelled] if the user dismissed the Apple sheet.
  static Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateRawNonce();

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256ofString(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Apple only returns the name on the very first authorization, so persist
    // it now in the same shape the profile screens use.
    await _saveAppleName(userCredential.user, appleCredential);

    return userCredential;
  }

  /// Stores the name Apple handed us on first sign-in, so the user doesn't
  /// have to retype it on the "About You" screen.
  ///
  /// Never overwrites a name that is already on the Firestore document.
  static Future<void> _saveAppleName(
    User? user,
    AuthorizationCredentialAppleID appleCredential,
  ) async {
    if (user == null) return;

    final parts = [
      appleCredential.givenName?.trim() ?? '',
      appleCredential.familyName?.trim() ?? '',
    ].where((p) => p.isNotEmpty);
    if (parts.isEmpty) return;

    final fullName = parts.join(' ');
    final preferredName = appleCredential.givenName?.trim().isNotEmpty == true
        ? appleCredential.givenName!.trim()
        : fullName;

    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final existing = (await docRef.get()).data();
      await docRef.set({
        if (existing?['fullName'] == null) 'fullName': fullName,
        if (existing?['preferredName'] == null) 'preferredName': preferredName,
      }, SetOptions(merge: true));

      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(fullName);
      }
    } catch (e) {
      // Non-fatal: the user can still fill this in on the profile screen.
      debugPrint('Failed to save Apple name: $e');
    }
  }

  /// Deletes the signed-in user's Firebase account.
  ///
  /// Apple requires apps to revoke the Apple refresh token when an account
  /// signed in with Apple is deleted, which needs a *fresh* authorization
  /// code — so Apple users are re-prompted before the delete. Google and
  /// email users go straight to [User.delete], exactly as before.
  ///
  /// Throws [SignInCancelled] if an Apple user dismissed the re-auth sheet,
  /// in which case the account is left untouched.
  ///
  /// [beforeDelete] runs after re-authentication succeeded and right before
  /// the Firebase account goes away — the place to purge the user's data while
  /// the session (and its ID token) is still valid.
  static Future<void> deleteAccount({
    Future<void> Function()? beforeDelete,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isAppleUser =
        user.providerData.any((p) => p.providerId == 'apple.com');

    if (isAppleUser) {
      final rawNonce = _generateRawNonce();

      final AuthorizationCredentialAppleID appleCredential;
      try {
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: _sha256ofString(rawNonce),
        );
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw const SignInCancelled();
        }
        rethrow;
      }

      await user.reauthenticateWithCredential(
        OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        ),
      );

      await beforeDelete?.call();

      await _auth.revokeTokenWithAuthorizationCode(
        appleCredential.authorizationCode,
      );
    } else {
      await beforeDelete?.call();
    }

    await _auth.currentUser?.delete();
  }

  /// True when the signed-in user's only way back in is an email + password.
  static bool get isPasswordUser {
    final user = _auth.currentUser;
    return user != null &&
        user.providerData.any((p) => p.providerId == 'password');
  }

  /// Re-authenticates an email/password user. Throws [FirebaseAuthException]
  /// (`wrong-password` / `invalid-credential`) on a bad password.
  static Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Re-authenticates a Google user. Throws [SignInCancelled] if the user
  /// dismisses the Google sheet.
  static Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _ensureInitialized();
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
  }

  static bool get isGoogleUser {
    final user = _auth.currentUser;
    return user != null &&
        user.providerData.any((p) => p.providerId == 'google.com');
  }

  static Future<void> logOut() async {
    await _google.signOut();
    await _auth.signOut();
  }




  static User? get currentUser => _auth.currentUser;
}
