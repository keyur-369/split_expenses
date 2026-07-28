import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
      debugPrint('⚠️  Empty email provided');
      return null;
    }

    debugPrint('🔍 Looking up user by email: $normalized');
    
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();

      debugPrint('📊 Query result: ${snap.docs.length} doc(s) found');
      
      if (snap.docs.isEmpty) {
        debugPrint('❌ No user found with email: $normalized');
        return null;
      }
      
      final userId = snap.docs.first.id;
      final userData = snap.docs.first.data() as Map<String, dynamic>;
      debugPrint('✅ Found user: ${userData['name']} ($userId)');
      return userId;
    } catch (e) {
      debugPrint('❌ Error looking up user by email: $e');
      if (e.toString().contains('permission-denied')) {
        debugPrint('⚠️  PERMISSION DENIED — check Firestore rules.');
      }
      rethrow;
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

  // Batch-fetch multiple user documents in parallel (avoids N sequential reads)
  Future<Map<String, Map<String, dynamic>>> getUserDocumentsBatch(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return {};
    try {
      final results = await Future.wait(
        uids.map((uid) => _db.collection('users').doc(uid).get()),
      );
      final Map<String, Map<String, dynamic>> userMap = {};
      for (final doc in results) {
        if (doc.exists) {
          userMap[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }
      return userMap;
    } catch (e) {
      return {};
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
    double? budgetLimit,
    String? currencyCode,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'ownerId': ownerId,
      'members': memberIds,
      'createdAt': createdAt.toUtc(),
      'currencyCode': currencyCode ?? 'INR',
    };
    if (budgetLimit != null) {
      data['budgetLimit'] = budgetLimit;
    }
    await _db.collection('groups').doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> updateGroupBudgetAndCurrency({
    required String groupId,
    required double? budgetLimit,
    required String currencyCode,
  }) async {
    final data = <String, dynamic>{
      'currencyCode': currencyCode,
      'budgetLimit': budgetLimit,
    };
    await _db.collection('groups').doc(groupId).update(data);
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
    // Delete expenses for this group
    final expenses = await _db
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (final doc in expenses.docs) {
      await doc.reference.delete();
    }
    // Delete settlements for this group
    final settlements = await _db
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .get();
    for (final doc in settlements.docs) {
      await doc.reference.delete();
    }
  }

  // Stream of paid settlement keys for a group (real-time)
  Stream<Set<String>> getSettlementsStream(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  // Fetch paid settlement keys once
  Future<Set<String>> getSettlementsOnce(String groupId) async {
    try {
      final snap = await _db
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      return {};
    }
  }

  // Fetch notes for all settlements once — returns key → note (empty if no note)
  Future<Map<String, String>> getSettlementNotesOnce(String groupId) async {
    try {
      final snap = await _db
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .get();
      final notes = <String, String>{};
      for (final doc in snap.docs) {
        final note = (doc.data()['note'] as String?)?.trim() ?? '';
        if (note.isNotEmpty) notes[doc.id] = note;
      }
      return notes;
    } catch (_) {
      return {};
    }
  }

  // Mark a settlement as paid. customKey overrides the default key.
  Future<void> markAsPaid({
    required String groupId,
    required String debtorId,
    required String creditorId,
    required String markedByUserId,
    required double amount,
    String? customKey,
    String? note,
  }) async {
    final key = customKey ?? '${debtorId}_$creditorId';
    final data = <String, dynamic>{
      'debtorId': debtorId,
      'creditorId': creditorId,
      'amount': amount,
      'markedBy': markedByUserId,
      'paidAt': DateTime.now().toUtc(),
    };
    if (note != null && note.trim().isNotEmpty) {
      data['note'] = note.trim();
    }
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(key)
        .set(data);
  }

  // Unmark a settlement (reopen it)
  Future<void> unmarkAsPaid({
    required String groupId,
    required String debtorId,
    required String creditorId,
    String? customKey,
  }) async {
    final key = customKey ?? '${debtorId}_$creditorId';
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .doc(key)
        .delete();
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
    String? category,
    String? currencyCode,
  }) async {
    await _db.collection('expenses').doc(id).set({
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitWith': splitWith,
      'groupId': groupId,
      'createdAt': createdAt.toUtc(),
      'category': category ?? 'General',
      if (currencyCode != null) 'currencyCode': currencyCode,
    });
  }

  // Delete a single expense document
  Future<void> deleteExpense(String expenseId) async {
    await _db.collection('expenses').doc(expenseId).delete();
  }

  // Remove a single user from a group's members array
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  // Update user profile data (e.g., name, upiId)
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }
}
