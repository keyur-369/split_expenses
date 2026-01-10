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

  Group({
    required this.id,
    required this.name,
    required this.participants,
    required this.expenses,
    required this.createdAt,
  });
}
