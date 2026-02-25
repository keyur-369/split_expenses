import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/participant.dart';
import '../models/expense.dart';
import '../storage/storage_service.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class GroupService extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  List<Group> _groups = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _groupsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot>> _expenseSubscriptions =
      {};

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    for (var subscription in _expenseSubscriptions.values) {
      subscription.cancel();
    }
    _expenseSubscriptions.clear();
    super.dispose();
  }

  Future<void> loadGroups({bool forceRefresh = false}) async {
    // If already listening and not forced, don't restart everything
    if (_groupsSubscription != null && !forceRefresh) return;

    // Only show hard loading states if we don't have any data yet
    if (_groups.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Cancel existing subscriptions before starting fresh
      _groupsSubscription?.cancel();
      for (var subscription in _expenseSubscriptions.values) {
        subscription.cancel();
      }
      _expenseSubscriptions.clear();

      // Set up real-time listener for groups
      _groupsSubscription = _firestoreService
          .getUserGroups(user.uid)
          .listen(
            (groupsSnapshot) async {
              final firestoreGroups = <Group>[];

              // Collect all unique member IDs across all groups for batch fetch
              final allMemberIds = <String>{};
              for (final doc in groupsSnapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final memberIds = List<String>.from(data['members'] ?? []);
                allMemberIds.addAll(memberIds);
              }

              // BATCH: fetch all user docs in parallel (one round-trip instead of N)
              final userDataMap = await _firestoreService.getUserDocumentsBatch(
                allMemberIds.toList(),
              );

              // PARALLEL: fetch all group expenses at the same time
              final expenseFutures = <String, Future<QuerySnapshot>>{};
              for (final doc in groupsSnapshot.docs) {
                expenseFutures[doc.id] =
                    _firestoreService.getGroupExpenses(doc.id).first;
              }
              final expenseSnapshots = await Future.wait(
                expenseFutures.values,
              );
              final expenseSnapshotMap = <String, QuerySnapshot>{};
              int i = 0;
              for (final docId in expenseFutures.keys) {
                expenseSnapshotMap[docId] = expenseSnapshots[i++];
              }

              for (final doc in groupsSnapshot.docs) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  final memberIds = List<String>.from(data['members'] ?? []);

                  // Build participants from batch-fetched user data
                  final participants = memberIds.map((memberId) {
                    final userData = userDataMap[memberId];
                    if (userData != null) {
                      return Participant(
                        id: memberId,
                        name: userData['name'] ?? 'Unknown',
                        email: userData['email'],
                        userId: memberId,
                      );
                    }
                    return Participant(
                      id: memberId,
                      name: 'Unknown User',
                      userId: memberId,
                    );
                  }).toList();

                  final participantMap = {
                    for (var p in participants) p.userId ?? p.id: p,
                  };

                  // Use the pre-fetched expense snapshot
                  final expensesSnapshot = expenseSnapshotMap[doc.id]!;
                  final expenses = expensesSnapshot.docs.map((expDoc) {
                    final expData = expDoc.data() as Map<String, dynamic>;
                    final paidByUserId = expData['paidBy'] ?? '';
                    final splitWithUserIds = List<String>.from(
                      expData['splitWith'] ?? [],
                    );
                    final payerParticipant = participantMap[paidByUserId];
                    final payerParticipantId =
                        payerParticipant?.id ?? paidByUserId;
                    final involvedParticipantIds = splitWithUserIds.map((uid) {
                      final participant = participantMap[uid];
                      return participant?.id ?? uid;
                    }).toList();

                    return Expense(
                      id: expDoc.id,
                      title: expData['title'] ?? '',
                      amount: (expData['amount'] ?? 0.0).toDouble(),
                      payerId: payerParticipantId,
                      involvedParticipantIds: involvedParticipantIds,
                      date:
                          (expData['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.now(),
                    );
                  }).toList();

                  // Fetch ownerId and paid settlements in parallel
                  final ownerId = data['ownerId'] as String?;
                  final paidKeys =
                      await _firestoreService.getSettlementsOnce(doc.id);
                  final paidNotes =
                      await _firestoreService.getSettlementNotesOnce(doc.id);

                  final group = Group(
                    id: doc.id,
                    name: data['name'] ?? '',
                    participants: participants,
                    expenses: expenses,
                    createdAt:
                        (data['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    ownerId: ownerId,
                    paidSettlementKeys: paidKeys,
                    paidSettlementNotes: paidNotes,
                  );

                  // Save to local Hive for offline access
                  await _storageService.addGroup(group);
                  firestoreGroups.add(group);

                  // Only create expense subscription if not already listening
                  if (!_expenseSubscriptions.containsKey(doc.id)) {
                    _expenseSubscriptions[doc.id] = _firestoreService
                        .getGroupExpenses(doc.id)
                        .listen((expensesSnapshot) async {
                      final groupIndex = _groups.indexWhere(
                        (g) => g.id == doc.id,
                      );
                      if (groupIndex == -1) return;

                      final currentGroup = _groups[groupIndex];
                      final participantMap = {
                        for (var p in currentGroup.participants)
                          p.userId ?? p.id: p,
                      };

                      final updatedExpenses = expensesSnapshot.docs
                          .map((expDoc) {
                            final expData =
                                expDoc.data() as Map<String, dynamic>;
                            final paidByUserId = expData['paidBy'] ?? '';
                            final splitWithUserIds = List<String>.from(
                              expData['splitWith'] ?? [],
                            );
                            final payerParticipant =
                                participantMap[paidByUserId];
                            final payerParticipantId =
                                payerParticipant?.id ?? paidByUserId;
                            final involvedParticipantIds =
                                splitWithUserIds.map((uid) {
                                  final participant = participantMap[uid];
                                  return participant?.id ?? uid;
                                }).toList();

                            return Expense(
                              id: expDoc.id,
                              title: expData['title'] ?? '',
                              amount: (expData['amount'] ?? 0.0).toDouble(),
                              payerId: payerParticipantId,
                              involvedParticipantIds: involvedParticipantIds,
                              date:
                                  (expData['createdAt'] as Timestamp?)
                                      ?.toDate() ??
                                  DateTime.now(),
                            );
                          })
                          .toList();

                      _groups[groupIndex] = Group(
                        id: currentGroup.id,
                        name: currentGroup.name,
                        participants: currentGroup.participants,
                        expenses: updatedExpenses,
                        createdAt: currentGroup.createdAt,
                        ownerId: currentGroup.ownerId,
                        paidSettlementKeys: currentGroup.paidSettlementKeys,
                        paidSettlementNotes: currentGroup.paidSettlementNotes,
                      );

                      await _storageService.addGroup(_groups[groupIndex]);
                      notifyListeners();
                    });
                  }
                } catch (e) {
                  debugPrint('Error loading group ${doc.id}: $e');
                }
              }

              // Cancel subscriptions for groups that no longer exist
              final currentGroupIds =
                  groupsSnapshot.docs.map((d) => d.id).toSet();
              final staleIds = _expenseSubscriptions.keys
                  .where((id) => !currentGroupIds.contains(id))
                  .toList();
              for (final id in staleIds) {
                _expenseSubscriptions[id]?.cancel();
                _expenseSubscriptions.remove(id);
              }

              _groups = firestoreGroups;
              _groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _isLoading = false;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Error in groups stream: $error');
              _groups = _storageService.getAllGroups();
              _groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _isLoading = false;
              notifyListeners();
            },
          );
    } else {
      // Not logged in, use local storage only
      _groups = _storageService.getAllGroups();
      _groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createGroup(String name) async {
    final user = FirebaseAuth.instance.currentUser;

    final newGroup = Group(
      id: const Uuid().v4(),
      name: name,
      participants: [],
      expenses: [],
      createdAt: DateTime.now(),
      ownerId: user?.uid,
    );

    // Local (Hive)
    await _storageService.addGroup(newGroup);

    // Optimistically update in-memory list so UI reflects the new group immediately
    _groups.add(newGroup);
    // Keep list ordering consistent (newest first)
    _groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();

    // Cloud (Firestore) if logged in
    if (user != null) {
      await _firestoreService.upsertGroup(
        id: newGroup.id,
        name: newGroup.name,
        ownerId: user.uid,
        createdAt: newGroup.createdAt,
        memberIds: [user.uid],
      );
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final box = _storageService.getGroupBox();
    await box.delete(groupId);

    // Cancel expense subscription for this group
    _expenseSubscriptions[groupId]?.cancel();
    _expenseSubscriptions.remove(groupId);

    // Optimistically update in-memory list so UI reflects the deletion immediately
    _groups.removeWhere((g) => g.id == groupId);
    notifyListeners();

    // Also delete from Firestore
    await _firestoreService.deleteGroup(groupId);
  }

  /// Mark a settlement as paid (owner only).
  /// [customKey] overrides the default "debtorId_creditorId" key —
  /// e.g. use "expId:debtorId_payerId" for expense-scoped payments.
  /// [note] is an optional owner message shown to all members.
  Future<void> markAsPaid({
    required Group group,
    required String debtorId,
    required String creditorId,
    required double amount,
    String? customKey,
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = customKey ?? '${debtorId}_$creditorId';
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      final updatedKeys =
          Set<String>.from(_groups[idx].paidSettlementKeys)..add(key);
      final updatedNotes =
          Map<String, String>.from(_groups[idx].paidSettlementNotes);
      if (note != null && note.trim().isNotEmpty) {
        updatedNotes[key] = note.trim();
      } else {
        updatedNotes.remove(key);
      }
      _groups[idx] = Group(
        id: _groups[idx].id,
        name: _groups[idx].name,
        participants: _groups[idx].participants,
        expenses: _groups[idx].expenses,
        createdAt: _groups[idx].createdAt,
        ownerId: _groups[idx].ownerId,
        paidSettlementKeys: updatedKeys,
        paidSettlementNotes: updatedNotes,
      );
      notifyListeners();
    }

    await _firestoreService.markAsPaid(
      groupId: group.id,
      debtorId: debtorId,
      creditorId: creditorId,
      markedByUserId: user.uid,
      amount: amount,
      customKey: key,
      note: note,
    );

    // Notify the debtor that their payment was confirmed
    try {
      // Find debtor's Firebase UID
      final debtorParticipant = group.participants.firstWhere(
        (p) => p.id == debtorId,
        orElse: () => Participant(id: debtorId, name: 'Unknown'),
      );
      final debtorUserId = debtorParticipant.userId;

      if (debtorUserId != null && debtorUserId != user.uid) {
        final creditorDoc = await _firestoreService.getUserDocument(user.uid);
        final creditorName = (creditorDoc?.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Someone';
        await NotificationService.sendPaymentConfirmedNotification(
          groupName: group.name,
          groupId: group.id,
          confirmedByName: creditorName,
          amount: amount,
          debtorUserId: debtorUserId,
          note: note,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Payment notification skipped: $e');
    }
  }

  /// Unmark a previously-paid settlement (reopen it).
  Future<void> unmarkAsPaid({
    required Group group,
    required String debtorId,
    required String creditorId,
    String? customKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = customKey ?? '${debtorId}_$creditorId';
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      final updatedKeys =
          Set<String>.from(_groups[idx].paidSettlementKeys)..remove(key);
      final updatedNotes =
          Map<String, String>.from(_groups[idx].paidSettlementNotes)
            ..remove(key);
      _groups[idx] = Group(
        id: _groups[idx].id,
        name: _groups[idx].name,
        participants: _groups[idx].participants,
        expenses: _groups[idx].expenses,
        createdAt: _groups[idx].createdAt,
        ownerId: _groups[idx].ownerId,
        paidSettlementKeys: updatedKeys,
        paidSettlementNotes: updatedNotes,
      );
      notifyListeners();
    }

    await _firestoreService.unmarkAsPaid(
      groupId: group.id,
      debtorId: debtorId,
      creditorId: creditorId,
      customKey: key,
    );
  }

  Future<void> addParticipant(
    Group group,
    String name, {
    String? email,
    String? phone,
    String? contactId,
    String? userId,
  }) async {
    debugPrint('➕ Adding participant: $name (email: $email, userId: $userId)');
    
    final newParticipant = Participant(
      id: const Uuid().v4(),
      name: name,
      email: email,
      phone: phone,
      contactId: contactId,
      userId: userId,
    );
    
    final user = FirebaseAuth.instance.currentUser;
    
    // Update Firestore first if user is logged in and participant has userId
    if (user != null && userId != null) {
      debugPrint('🌐 Adding participant to Firestore (cross-device sync enabled)');
      
      final memberIds = <String>{
        user.uid,
        ...group.participants
            .where((p) => p.userId != null)
            .map((p) => p.userId!),
        userId, // Add the new user
      }.toList();

      debugPrint('📝 Updating group members: $memberIds');

      await _firestoreService.upsertGroup(
        id: group.id,
        name: group.name,
        ownerId: user.uid,
        createdAt: group.createdAt,
        memberIds: memberIds,
      );

      // Send notification to the newly added member
      try {
        final adderDoc = await _firestoreService.getUserDocument(user.uid);
        final adderName = (adderDoc?.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Someone';
        await NotificationService.sendMemberAddedNotification(
          groupName: group.name,
          groupId: group.id,
          addedByName: adderName,
          newMemberUserIds: [userId],
        );
      } catch (e) {
        debugPrint('⚠️ Member notification skipped: $e');
      }
      
      // Manually fetch the updated group data from Firestore
      // to ensure we have the latest participant list
      try {
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(group.id)
            .get();
            
        if (groupDoc.exists) {
          final data = groupDoc.data() as Map<String, dynamic>;
          final updatedMemberIds = List<String>.from(data['members'] ?? []);
          final updatedParticipants = <Participant>[];
          
          debugPrint('🔄 Reloading ${updatedMemberIds.length} participants from Firestore');
          
          for (final memberId in updatedMemberIds) {
            try {
              final userDoc = await _firestoreService.getUserDocument(memberId);
              if (userDoc != null && userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                updatedParticipants.add(
                  Participant(
                    id: memberId,
                    name: userData['name'] ?? 'Unknown',
                    email: userData['email'],
                    userId: memberId,
                  ),
                );
              }
            } catch (e) {
              debugPrint('Error loading user $memberId: $e');
            }
          }
          
          // Update the group with new participants
          final updatedGroup = Group(
            id: group.id,
            name: group.name,
            participants: updatedParticipants,
            expenses: group.expenses,
            createdAt: group.createdAt,
          );
          
          // Save to local storage
          await _storageService.addGroup(updatedGroup);
          
          // Update in-memory list
          final index = _groups.indexWhere((g) => g.id == group.id);
          if (index != -1) {
            _groups[index] = updatedGroup;
          }
          
          debugPrint('✅ Participant added successfully (Firestore + local)');
          notifyListeners();
        }
      } catch (e) {
        debugPrint('❌ Error reloading group after adding participant: $e');
      }
    } else {
      debugPrint('💾 Adding participant locally only (no cross-device sync)');
      debugPrint('   Reason: user=${user != null ? "logged in" : "not logged in"}, userId=${userId != null ? "provided" : "null"}');
      
      // For local-only participants (no userId), update locally
      group.participants.add(newParticipant);
      await group.save();

      // Keep in-memory list in sync
      final index = _groups.indexWhere((g) => g.id == group.id);
      if (index != -1) {
        _groups[index] = group;
      }
      
      debugPrint('✅ Participant added locally');
      notifyListeners();
    }
  }

  Future<void> addExpense(
    Group group,
    String title,
    double amount,
    String payerId,
    List<String> involvedIds,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();

    final newExpense = Expense(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      payerId: payerId,
      involvedParticipantIds: involvedIds,
      date: now,
    );
    group.expenses.add(newExpense);
    await group.save();

    // Keep in-memory list in sync
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
    }

    // Also store in Firestore if logged in
    if (user != null) {
      // Convert participant IDs to user IDs (Firebase UIDs) for cross-device compatibility
      // Find payer's userId
      final payerParticipant = group.participants.firstWhere(
        (p) => p.id == payerId,
        orElse: () => Participant(id: payerId, name: 'Unknown'),
      );
      final paidByUserId = payerParticipant.userId ?? payerId;

      // Find involved participants' userIds
      final splitWithUserIds = involvedIds.map((participantId) {
        final participant = group.participants.firstWhere(
          (p) => p.id == participantId,
          orElse: () => Participant(id: participantId, name: 'Unknown'),
        );
        return participant.userId ?? participantId;
      }).toList();

      await _firestoreService.addExpense(
        id: newExpense.id,
        title: newExpense.title,
        amount: newExpense.amount,
        paidBy: paidByUserId, // Use userId instead of participant ID
        splitWith: splitWithUserIds, // Use userIds instead of participant IDs
        groupId: group.id,
        createdAt: now,
      );

      // Send notification to all split members (except the payer)
      try {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📢 [GroupService] addExpense — building notification…');
        debugPrint('   paidByUserId    : $paidByUserId');
        debugPrint('   splitWithUserIds: $splitWithUserIds');

        final payerDoc = await _firestoreService.getUserDocument(user.uid);
        final payerName = (payerDoc?.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Someone';
        debugPrint('   payerName       : $payerName');

        // Only notify UIDs that are real Firebase user IDs (not local participant IDs)
        final notifyUserIds = splitWithUserIds
            .where((uid) => uid.length > 10) // real Firebase UIDs are long
            .toList();
        debugPrint('   notifyUserIds (filtered, len>10): $notifyUserIds');

        if (notifyUserIds.isEmpty) {
          debugPrint('   ⚠️  notifyUserIds is empty — no notification sent.');
          debugPrint('   Tip: Participants must be linked to Firebase accounts.');
        } else {
          await NotificationService.sendExpenseNotification(
            groupName: group.name,
            groupId: group.id,
            expenseId: newExpense.id,
            expenseTitle: title,
            totalAmount: amount,
            payerName: payerName,
            payerUserId: paidByUserId,
            splitUserIds: notifyUserIds,
            splitCount: splitWithUserIds.length,
          );
        }
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      } catch (e) {
        debugPrint('⚠️ Expense notification skipped: $e');
      }
    }

    notifyListeners();
  }

  Future<void> deleteExpense(Group group, String expenseId) async {
    group.expenses.removeWhere((e) => e.id == expenseId);
    await group.save();

    // Keep in-memory list in sync
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
    }

    notifyListeners();
  }

  /// Calculates net balances: Participant ID -> Amount
  /// Positive: Owed money (Credit)
  /// Negative: Owes money (Debt)
  Map<String, double> getNetBalances(Group group) {
    Map<String, double> balances = {};

    // Initialize to 0
    for (var p in group.participants) {
      balances[p.id] = 0.0;
    }

    for (var expense in group.expenses) {
      if (expense.involvedParticipantIds.isEmpty) continue;

      double splitAmount =
          expense.amount / expense.involvedParticipantIds.length;

      // Payer gets credit (+ paid amount)
      // Note: If payer is NOT in participants list (rare but possible logic), add them?
      // "If the payer is included, they owe their own share" implies logic handles it.

      // Update Payer
      if (!balances.containsKey(expense.payerId))
        balances[expense.payerId] = 0.0;
      balances[expense.payerId] =
          (balances[expense.payerId] ?? 0.0) + expense.amount;

      // Update Involved
      for (var id in expense.involvedParticipantIds) {
        if (!balances.containsKey(id)) balances[id] = 0.0;
        balances[id] = (balances[id] ?? 0.0) - splitAmount;
      }
    }
    return balances;
  }

  /// Returns a list of strings describing debts: "Alice owes Bob $10.00"
  List<String> getSettlements(Group group) {
    Map<String, double> balances = getNetBalances(group);

    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((id, amount) {
      if (amount < -0.01) debtors.add(MapEntry(id, amount));
      if (amount > 0.01) creditors.add(MapEntry(id, amount));
    });

    // Sort by magnitude desc (optional heuristic)
    debtors.sort(
      (a, b) => a.value.compareTo(b.value),
    ); // Ascending (most negative first)
    creditors.sort(
      (a, b) => b.value.compareTo(a.value),
    ); // Descending (most positive first)

    List<String> settlements = [];

    int i = 0; // debtors index
    int j = 0; // creditors index

    int safetyCount = 0;
    while (i < debtors.length && j < creditors.length) {
      if (safetyCount++ > 1000) {
        print("Safety break triggered in getSettlements");
        break;
      }

      var debtor = debtors[i];
      var creditor = creditors[j];

      // Amount to settle is min of abs(debt) and credit
      double amount = (-debtor.value) < creditor.value
          ? (-debtor.value)
          : creditor.value;

      // Prevent infinite loop if amount is effectively zero
      if (amount < 0.0001) {
        i++;
        j++;
        continue;
      }

      // Name lookup
      String debtorName = group.participants
          .firstWhere(
            (p) => p.id == debtor.key,
            orElse: () => Participant(id: '?', name: 'Unknown'),
          )
          .name;
      String creditorName = group.participants
          .firstWhere(
            (p) => p.id == creditor.key,
            orElse: () => Participant(id: '?', name: 'Unknown'),
          )
          .name;

      settlements.add(
        "$debtorName owes $creditorName \$${amount.toStringAsFixed(2)}",
      );

      // Adjust remaining
      double remainingDebt = debtor.value + amount;
      double remainingCredit = creditor.value - amount;

      // Update local values for next iteration
      debtors[i] = MapEntry(debtor.key, remainingDebt);
      creditors[j] = MapEntry(creditor.key, remainingCredit);

      // Relaxed thresholds slightly to handle float imprecision
      if (remainingDebt.abs() < 0.001) i++;
      if (remainingCredit < 0.001) j++;
    }

    return settlements;
  }

  // Update Participant
  Future<void> updateParticipant(
    Group group,
    Participant participant, {
    String? newName,
    String? email,
    String? phone,
  }) async {
    final index = group.participants.indexWhere((p) => p.id == participant.id);
    if (index != -1) {
      group.participants[index] = Participant(
        id: participant.id,
        name: newName ?? participant.name,
        email: email ?? participant.email,
        phone: phone ?? participant.phone,
        contactId: participant.contactId,
      );
      await group.save();
      notifyListeners();
    }
  }

  // Delete Participant
  Future<String?> deleteParticipant(Group group, String participantId) async {
    // Check if participant is involved in any expense
    bool isInvolved = group.expenses.any(
      (e) =>
          e.payerId == participantId ||
          e.involvedParticipantIds.contains(participantId),
    );

    if (isInvolved) {
      return "Cannot delete: Participant is part of existing expenses.";
    }

    group.participants.removeWhere((p) => p.id == participantId);
    await group.save();
    notifyListeners();
    return null; // Success
  }
}
