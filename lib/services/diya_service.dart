import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiyaService {
  static String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // Lit the Diya + Firestore  save
  static Future<void> lightDiya() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final dateKey = _todayKey();
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final logRef = userRef.collection('diyaLogs').doc(dateKey);

    final logSnap = await logRef.get();
    if (!logSnap.exists) {
      // Diya lit today
      await logRef.set({
        'lit': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await userRef.update({
        'totalDiyasLit': FieldValue.increment(1),
        'lastLitDate': dateKey,
      });
    }
  }

  // App open hone par check karo — aaj diya jala tha?
  static Future<bool> isDiyaLitToday() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final dateKey = _todayKey();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('diyaLogs')
        .doc(dateKey)
        .get();

    return snap.exists;
  }

  // Weekly stats
  static Future<int> getWeeklyCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return 0;

    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('diyaLogs').doc(dateKey).get();
      if (snap.exists) count++;
    }
    return count;
  }

  // Lifetime stats
  static Future<int> getLifetimeCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return 0;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(userId).get();
    return (snap.data()?['totalDiyasLit'] as num?)?.toInt() ?? 0;
  }
}