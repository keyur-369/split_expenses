import 'package:hive/hive.dart';
import 'participant.dart';
import 'expense.dart';

part 'group.g.dart';

@HiveType(typeId: 2)
class Group extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  List<Participant> participants;

  @HiveField(3)
  List<Expense> expenses;

  @HiveField(4)
  final DateTime createdAt;

  // Not stored in Hive — loaded from Firestore at runtime
  final String? ownerId;

  /// Keys of settlements marked as paid, e.g. "expId:debtorId_payerId"
  final Set<String> paidSettlementKeys;

  /// Optional owner note per settlement key (same keys as paidSettlementKeys)
  final Map<String, String> paidSettlementNotes;

  Group({
    required this.id,
    required this.name,
    required this.participants,
    required this.expenses,
    required this.createdAt,
    this.ownerId,
    Set<String>? paidSettlementKeys,
    Map<String, String>? paidSettlementNotes,
  })  : paidSettlementKeys = paidSettlementKeys ?? {},
        paidSettlementNotes = paidSettlementNotes ?? {};
}
