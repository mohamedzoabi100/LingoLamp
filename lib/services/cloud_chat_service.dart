import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the collection reference for the current user's chats.
  CollectionReference<Map<String, dynamic>> _chatsCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(uid).collection('chats');
  }

  /// Returns the messages collection for a conversation.
  CollectionReference<Map<String, dynamic>> _messagesCollection(String conversationId) {
    return _chatsCollection().doc(conversationId).collection('messages');
  }

  /// Get all conversations for the current user.
  Future<List<Map<String, dynamic>>> getConversations() async {
    final snapshot = await _chatsCollection().get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Listen to conversations in real-time.
  Stream<List<Map<String, dynamic>>> listenToConversations() {
    return _chatsCollection().snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList()
    );
  }

  /// Get all messages for a conversation.
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final snapshot = await _messagesCollection(conversationId).orderBy('timestamp').get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Listen to messages in a conversation in real-time.
  Stream<List<Map<String, dynamic>>> listenToMessages(String conversationId) {
    return _messagesCollection(conversationId).orderBy('timestamp').snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList()
    );
  }

  /// Add a new conversation.
  Future<void> addConversation(Map<String, dynamic> conversationData) async {
    await _chatsCollection().add({
      ...conversationData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a message to a conversation.
  Future<void> addMessage(String conversationId, Map<String, dynamic> messageData) async {
    await _messagesCollection(conversationId).add({
      ...messageData,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Optionally update conversation's updatedAt
    await _chatsCollection().doc(conversationId).update({'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String conversationId) async {
    final batch = _firestore.batch();
    final messagesSnapshot = await _messagesCollection(conversationId).get();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_chatsCollection().doc(conversationId));
    await batch.commit();
  }
} 