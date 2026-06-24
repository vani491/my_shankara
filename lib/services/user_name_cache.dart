import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared cached preferred name — home aur drawer dono use karte hain.
class UserNameCache {
  UserNameCache._();

  static String value = 'Sishya';

  static Future<String> refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      value = 'Sishya';
      return value;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = doc.data()?['preferredName'] as String?;
      value = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Sishya';
    } catch (_) {
      // error pe purana value rakho
    }
    return value;
  }
}