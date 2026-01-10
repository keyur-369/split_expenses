import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch groups for user
  Stream<QuerySnapshot> getUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots();
  }

  // Fetch expenses for a group
  Stream<QuerySnapshot> getGroupExpenses(String groupId) {
    return _db
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .snapshots();
  }

  // Lookup userId (uid) by email in users collection
  Future<String?> getUserIdByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  // Get user document by uid
  Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      return await _db.collection('users').doc(uid).get();
    } catch (e) {
      return null;
    }
  }

  // Expose db for direct access if needed
  FirebaseFirestore get db => _db;

  // Add / update group, including members array of userIds
  Future<void> upsertGroup({
    required String id,
    required String name,
    required String ownerId,
    required DateTime createdAt,
    required List<String> memberIds,
  }) async {
    await _db.collection('groups').doc(id).set({
      'name': name,
      'ownerId': ownerId,
      'members': memberIds,
      'createdAt': createdAt.toUtc(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
    // Optionally, also delete expenses for this group
    final expenses = await _db
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (final doc in expenses.docs) {
      await doc.reference.delete();
    }
  }

  // Add expense
  Future<void> addExpense({
    required String id,
    required String title,
    required double amount,
    required String paidBy,
    required List<String> splitWith,
    required String groupId,
    required DateTime createdAt,
  }) async {
    await _db.collection('expenses').doc(id).set({
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitWith': splitWith,
      'groupId': groupId,
      'createdAt': createdAt.toUtc(),
    });
  }
}
