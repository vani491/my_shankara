import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/aa_guru_chatbot.dart' show deleteDifyConversationViaProxy;
import 'auth_service.dart';
import 'notification_service.dart';
import 'user_name_cache.dart';

/// Deletes everything we hold about the signed-in user.
///
/// What goes, in this order:
///  1. a "tombstone" is written (see below),
///  2. every Dify conversation, via the proxy (Dify has no "delete all data
///     for user" call, only `DELETE /conversations/{id}`),
///  3. Firestore: chats + messages, diya logs, the `users/{uid}` profile doc,
///  4. the Firebase Auth account itself.
///
/// The proxy checks conversation ownership against `users/{uid}/chats/{id}`,
/// so step 2 must finish before step 3. If any Dify delete fails the whole
/// thing stops *before* anything else is touched, so the user can retry.
///
/// Tombstone: `deletedAccounts/{sha256(email)}` keeps only a hash of the email
/// and the trial start date, so a returning user cannot get a fresh free
/// trial by deleting and re-registering (see [previousTrialStart]).
///
/// Firestore rules must allow it, e.g.:
/// ```
/// match /deletedAccounts/{key} {
///   allow get, create: if request.auth != null;
///   allow list, update, delete: if false;
/// }
/// ```
class AccountDeletionService {
  AccountDeletionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? _emailOf(User user) {
    final direct = user.email;
    if (direct != null && direct.isNotEmpty) return direct;
    for (final p in user.providerData) {
      final e = p.email;
      if (e != null && e.isNotEmpty) return e;
    }
    return null;
  }

  static DocumentReference<Map<String, dynamic>>? _tombstoneRef(User user) {
    final email = _emailOf(user);
    if (email == null) return null;
    final key =
        sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return _db.collection('deletedAccounts').doc(key);
  }

  /// The trial start date this email had before it was deleted, or null if
  /// the email is new (or never started a trial). Fails open: a read error
  /// means "no earlier trial", never a blocked sign-up.
  static Future<Timestamp?> previousTrialStart(User user) async {
    try {
      final snap = await _tombstoneRef(user)?.get();
      final ts = snap?.data()?['trialStartDate'];
      return ts is Timestamp ? ts : null;
    } catch (e) {
      debugPrint('previousTrialStart failed (treating as new email): $e');
      return null;
    }
  }

  /// Deletes the account and all its data. The caller must already have
  /// re-authenticated email/Google users (see [AuthService]); Apple users are
  /// re-prompted inside [AuthService.deleteAccount].
  static Future<void> deleteAccountAndData() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final uid = user.uid;

    await AuthService.deleteAccount(beforeDelete: () => _purge(user, uid));

    // The account is gone; clear what is left on this device.
    try {
      await AuthService.logOut();
    } catch (_) {
      // Already signed out by the delete.
    }
    UserNameCache.value = 'Sishya';
    try {
      await NotificationService.instance.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      for (final key in const [
        'isOnboarded',
        'notifications_enabled',
        'notif_hour',
        'notif_minute',
      ]) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Local cleanup after account deletion failed: $e');
    }
  }

  static Future<void> _purge(User user, String uid) async {
    final userRef = _db.collection('users').doc(uid);

    await _writeTombstone(user, userRef);

    // Dify first (needs the chat docs for the proxy's ownership check).
    final chats = await userRef.collection('chats').get();
    for (final chat in chats.docs) {
      final conversationId = chat.data()['difyConversationId'];
      if (conversationId is String && conversationId.isNotEmpty) {
        await deleteDifyConversationViaProxy(conversationId);
      }
    }

    for (final chat in chats.docs) {
      await _deleteCollection(chat.reference.collection('messages'));
      await chat.reference.delete();
    }
    await _deleteCollection(userRef.collection('diyaLogs'));
    await userRef.delete();
  }

  /// Best effort: losing the tombstone costs us trial-abuse protection, but it
  /// must never stop someone from deleting their account.
  static Future<void> _writeTombstone(
    User user,
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    try {
      final ref = _tombstoneRef(user);
      if (ref == null) return;
      if ((await ref.get()).exists) return; // keep the earliest trial date

      final profile = (await userRef.get()).data();
      final trial = profile?['trialStartDate'];
      await ref.set({
        'trialStartDate': trial is Timestamp ? trial : null,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Writing deletion tombstone failed: $e');
    }
  }

  /// Firestore does not cascade-delete subcollections; delete in batches
  /// (a batch holds at most 500 writes).
  static Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
