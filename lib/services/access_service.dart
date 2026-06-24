import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccessService {
  static const int trialLengthDays = 30;

  /// Returns true if the signed-in user may use premium features
  /// (active subscriber OR still within trial). Guests return false.
  static Future<bool> hasAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return true; // no data yet → don't block

      if (data['subscription_status'] == 'active') return true;

      final ts = data['trialStartDate'];
      if (ts is Timestamp) {
        final start = ts.toDate();
        final elapsed = DateTime.now().difference(start).inDays;
        return elapsed < trialLengthDays; // within trial
      }
      return true; // no trialStartDate yet → safe fallback, don't block
    } catch (_) {
      return true; // on error, don't lock the user out
    }
  }
}
