import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  /// Save one message (user or bot)
  Future<void> saveMessage({
    required String chatId,
    required String text,
    required String sender,
  }) async {
    final chatRef = _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(chatId);

    // chat summary
    await chatRef.set({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'title': text.length > 20 ? text.substring(0, 20) : text,
    }, SetOptions(merge: true));

    // message
    await chatRef.collection('messages').add({
      'text': text,
      'sender': sender,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Load all messages of a chat
  Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }
}
