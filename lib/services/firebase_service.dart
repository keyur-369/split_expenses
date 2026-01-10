// Firebase Service Template for Future Cloud Sync
// To use this service:
// 1. Uncomment Firebase dependencies in pubspec.yaml
// 2. Set up Firebase project and add config files
// 3. Initialize Firebase in main.dart
// 4. Replace StorageService with FirebaseService or use both for hybrid storage

/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/participant.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Groups collection reference
  CollectionReference get _groupsCollection => _firestore.collection('groups');

  // Get user's groups
  Stream<List<Group>> getUserGroups() {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    return _groupsCollection
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _groupFromFirestore(doc);
      }).toList();
    });
  }

  // Create a new group
  Future<void> createGroup(Group group) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    await _groupsCollection.doc(group.id).set({
      'userId': currentUserId,
      'name': group.name,
      'participants': group.participants.map((p) => _participantToMap(p)).toList(),
      'expenses': group.expenses.map((e) => _expenseToMap(e)).toList(),
      'createdAt': group.createdAt.toIso8601String(),
    });
  }

  // Update a group
  Future<void> updateGroup(Group group) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    await _groupsCollection.doc(group.id).update({
      'name': group.name,
      'participants': group.participants.map((p) => _participantToMap(p)).toList(),
      'expenses': group.expenses.map((e) => _expenseToMap(e)).toList(),
    });
  }

  // Delete a group
  Future<void> deleteGroup(String groupId) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    await _groupsCollection.doc(groupId).delete();
  }

  // Sign in with email
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Helper: Convert Group from Firestore
  Group _groupFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      participants: (data['participants'] as List?)
              ?.map((p) => _participantFromMap(p))
              .toList() ??
          [],
      expenses: (data['expenses'] as List?)
              ?.map((e) => _expenseFromMap(e))
              .toList() ??
          [],
      createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Helper: Convert Participant to Map
  Map<String, dynamic> _participantToMap(Participant participant) {
    return {
      'id': participant.id,
      'name': participant.name,
      'email': participant.email,
      'phone': participant.phone,
      'contactId': participant.contactId,
    };
  }

  // Helper: Convert Map to Participant
  Participant _participantFromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'],
      phone: map['phone'],
      contactId: map['contactId'],
    );
  }

  // Helper: Convert Expense to Map
  Map<String, dynamic> _expenseToMap(Expense expense) {
    return {
      'id': expense.id,
      'title': expense.title,
      'amount': expense.amount,
      'payerId': expense.payerId,
      'involvedParticipantIds': expense.involvedParticipantIds,
      'date': expense.date.toIso8601String(),
    };
  }

  // Helper: Convert Map to Expense
  Expense _expenseFromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      payerId: map['payerId'] ?? '',
      involvedParticipantIds: List<String>.from(map['involvedParticipantIds'] ?? []),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Share group with another user by email
  Future<void> shareGroup(String groupId, String email) async {
    // Implementation for sharing groups
    // This could involve:
    // 1. Adding the user to a sharedGroups collection
    // 2. Sending an invitation email
    // 3. Creating a notification
  }

  // Send expense notification to participants
  Future<void> notifyParticipants(String groupId, String expenseId) async {
    // Implementation for sending notifications
    // This could use Firebase Cloud Messaging or email
  }
}
*/

// Placeholder class to prevent import errors when Firebase is not set up
class FirebaseService {
  FirebaseService() {
    throw UnimplementedError(
      'Firebase is not set up. Please follow the UPGRADE_GUIDE.md to enable Firebase.',
    );
  }
}

