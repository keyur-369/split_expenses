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
    if (normalized.isEmpty) {
      print('⚠️  Empty email provided');
      return null;
    }

    print('🔍 Looking up user by email: $normalized');
    print('   Querying collection: users');
    print('   Query: where email == $normalized');
    
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();

      print('📊 Query completed. Documents found: ${snap.docs.length}');
      
      if (snap.docs.isEmpty) {
        print('❌ No user found with email: $normalized');
        print('   This means either:');
        print('   1. The user has not registered yet');
        print('   2. The email in the database is different (check case/spaces)');
        print('   3. The user document does not have an "email" field');
        return null;
      }
      
      final userId = snap.docs.first.id;
      final userData = snap.docs.first.data() as Map<String, dynamic>;
      print('✅ Found user with email $normalized');
      print('   User ID: $userId');
      print('   User name: ${userData['name'] ?? 'N/A'}');
      print('   Email in DB: ${userData['email'] ?? 'N/A'}');
      return userId;
    } catch (e) {
      print('❌ Error looking up user by email: $e');
      print('   Error type: ${e.runtimeType}');
      if (e.toString().contains('permission-denied')) {
        print('⚠️  PERMISSION DENIED: Firestore rules are still blocking this query!');
        print('   Please verify:');
        print('   1. Rules are published in Firebase Console');
        print('   2. You are logged in (request.auth != null)');
        print('   3. Rules allow: allow read: if request.auth != null;');
      }
      rethrow; // Re-throw so the caller can handle it
    }
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
