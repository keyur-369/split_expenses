import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/participant.dart';

class StorageService {
  static const String boxName = 'groups_box';

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(GroupAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(ParticipantAdapter());
    await Hive.openBox<Group>(boxName);
  }

  Box<Group> getGroupBox() {
    return Hive.box<Group>(boxName);
  }

  // Helper to add a group
  Future<void> addGroup(Group group) async {
    final box = getGroupBox();
    await box.put(group.id, group);
  }

  // Helper to get all groups
  List<Group> getAllGroups() {
    final box = getGroupBox();
    return box.values.toList();
  }

  // Update/Save is handled by HiveObject's save() or strictly putting back in box.
  // Since we use objects, we should be careful to save() if we modify in place.
  // However, for simpler flow, we might just call .save() on the object if it extends HiveObject.
}
