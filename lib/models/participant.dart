import 'package:hive/hive.dart';

part 'participant.g.dart';

@HiveType(typeId: 0)
class Participant {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String? phone;

  @HiveField(4)
  final String? contactId; // For linking with device contacts

  @HiveField(5)
  final String? userId; // Firebase UID link (optional)

  Participant({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.contactId,
    this.userId,
  });

  // Helper method to get display info
  String get displayInfo {
    if (email != null && email!.isNotEmpty) return email!;
    if (phone != null && phone!.isNotEmpty) return phone!;
    return name;
  }

  // Helper method to check if participant has contact info
  bool get hasContactInfo =>
      (email != null && email!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty);
}
