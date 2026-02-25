import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/participant.dart';
import '../services/group_service.dart';
import '../widgets/expense_tile.dart';
import '../widgets/add_participant_dialog.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'add_expense_screen.dart';
import 'settle_up_screen.dart';
import 'expense_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // ... (Dialog methods: _showAddParticipantDialog, _showEdit..., _confirmDelete...)
  // I will copy-paste them from previous file to ensure no functionality is lost, or refactor to separate file ideally.
  // For safety, I'll include them here inline again.

  void _showAddParticipantDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AddParticipantDialog(
        onAdd: (name, {email, phone, contactId}) async {
          String? userId;
          if (email != null && email.isNotEmpty) {
            // Check if user is logged in first
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'You must be logged in to add participants by email.',
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            
            debugPrint('👤 Current user: ${currentUser.uid} (${currentUser.email})');
            
            // Show loading indicator while looking up user
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Looking up user...'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
            
            try {
              userId = await FirestoreService().getUserIdByEmail(email);
            } catch (e) {
              // Handle permission errors
              if (e.toString().contains('permission-denied')) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Database permission error. Please update Firestore security rules to allow email lookup.',
                      ),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              } else {
                // Other errors
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error looking up user: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
              return; // Don't proceed with adding participant
            }
            
            // If email was provided but user not found, show error
            if (userId == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'User with email "$email" not found. They need to register first.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return; // Don't add the participant
            }
          }

          // Add locally (and update Firestore members via GroupService)
          await Provider.of<GroupService>(
            context,
            listen: false,
          ).addParticipant(
            group,
            name,
            email: email,
            phone: phone,
            contactId: contactId,
            userId: userId,
          );
          
          // Show success message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name added successfully!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditParticipantDialog(
    BuildContext context,
    Group group,
    Participant person,
  ) {
    final TextEditingController _nameController = TextEditingController(
      text: person.name,
    );
    final TextEditingController _emailController = TextEditingController(
      text: person.email ?? '',
    );
    final TextEditingController _phoneController = TextEditingController(
      text: person.phone ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Participant"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name *"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email (optional)",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone (optional)",
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                Provider.of<GroupService>(
                  context,
                  listen: false,
                ).updateParticipant(
                  group,
                  person,
                  newName: _nameController.text,
                  email: _emailController.text.isEmpty
                      ? null
                      : _emailController.text,
                  phone: _phoneController.text.isEmpty
                      ? null
                      : _phoneController.text,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteParticipant(
    BuildContext context,
    Group group,
    Participant person,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Person?"),
        content: Text("Are you sure you want to delete '${person.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await Provider.of<GroupService>(
                context,
                listen: false,
              ).deleteParticipant(group, person.id);

              if (error != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group?"),
        content: Text(
          "Delete '${group.name}' permanently? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<GroupService>(
                context,
                listen: false,
              ).deleteGroup(group.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Payment Reminder
  // ─────────────────────────────────────────────────────────────

  /// Shows a bottom sheet so the owner can choose (or type) a reminder message
  /// and send it to all members who still owe money.
  void _showReminderSheet(BuildContext context, Group group) {
    final TextEditingController _customController = TextEditingController();
    bool _sending = false;

    final List<String> _quickMessages = [
      '⏰ Hey! Don\'t forget to pay your split in "${group.name}".',
      '💸 Friendly reminder: Your payment is pending in "${group.name}". Please settle up!',
      '🙏 Please pay your share in "${group.name}" at your earliest convenience.',
      '💰 Just a nudge — you still owe money in "${group.name}". Pay when you can!',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005041).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF005041),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Payment Reminder',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Notify members who owe money',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick message chips
              Text(
                'Quick Messages',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickMessages.map((msg) {
                  return GestureDetector(
                    onTap: () => setModalState(
                      () => _customController.text = msg,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF005041).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF005041).withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        msg.substring(0, msg.length > 40 ? 40 : msg.length) +
                            (msg.length > 40 ? '…' : ''),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF005041),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Custom message field
              Text(
                'Or type a custom message',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write your reminder here…',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 20),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending
                      ? null
                      : () async {
                          final msg = _customController.text.trim();
                          if (msg.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter or select a message.'),
                              ),
                            );
                            return;
                          }
                          setModalState(() => _sending = true);
                          await _sendPaymentReminder(group, msg);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Sending…' : 'Send Reminder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005041),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Computes who still owes money in this group and sends them a reminder.
  Future<void> _sendPaymentReminder(Group group, String message) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Collect debtors — participants who owe money (net negative balance)
      // across all unpaid expenses, and have a linked Firebase userId
      final Map<String, double> owes = {}; // participantId -> amount owed

      for (final expense in group.expenses) {
        final splitCount = expense.involvedParticipantIds.length;
        if (splitCount == 0) continue;
        final share = expense.amount / splitCount;

        for (final pid in expense.involvedParticipantIds) {
          if (pid == expense.payerId) continue;
          final key = '${expense.id}:${pid}_${expense.payerId}';
          final alreadyPaid = group.paidSettlementKeys.contains(key);
          if (!alreadyPaid) {
            owes[pid] = (owes[pid] ?? 0) + share;
          }
        }
      }

      // Map participant IDs → Firebase UIDs
      final List<String> debtorUids = [];
      for (final pid in owes.keys) {
        final participant = group.participants.firstWhere(
          (p) => p.id == pid,
          orElse: () => Participant(id: pid, name: ''),
        );
        if (participant.userId != null && participant.userId!.isNotEmpty) {
          debtorUids.add(participant.userId!);
        }
      }

      if (debtorUids.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No members with outstanding balances found, or no linked accounts.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Fetch owner name
      final ownerDoc = await FirestoreService().getUserDocument(currentUser.uid);
      final ownerName = (ownerDoc?.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Group Owner';

      // Send notification to each debtor
      await NotificationService.sendReminderNotification(
        groupName: group.name,
        groupId: group.id,
        senderName: ownerName,
        message: message,
        targetUserIds: debtorUids,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Reminder sent to ${debtorUids.length} member(s)!',
            ),
            backgroundColor: const Color(0xFF005041),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupService>(
      builder: (context, service, child) {
        // Always use the latest version of this group from the service
        final group = service.groups.firstWhere(
          (g) => g.id == widget.group.id,
          orElse: () => widget.group,
        );

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(
              130,
            ), // Height for Title + TabBar usually
            child: AppBar(
              toolbarHeight: 80, // Taller toolbar for title
              title: Text(
                group.name,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              centerTitle: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: Theme.of(context).iconTheme.color,
                  padding: EdgeInsets.zero,
                ),
              ),
              actions: [
                // 🔔 Reminder bell — only for group owner
                if (FirebaseAuth.instance.currentUser?.uid == group.ownerId)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005041).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF005041).withOpacity(0.2),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_active_rounded,
                        size: 20,
                        color: Color(0xFF005041),
                      ),
                      tooltip: 'Send Payment Reminder',
                      onPressed: () => _showReminderSheet(context, group),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                    ),
                    tooltip: "Balances",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettleUpScreen(group: group),
                        ),
                      );
                    },
                    color: Theme.of(context).iconTheme.color,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    tooltip: "Delete Group",
                    onPressed: () => _confirmDeleteGroup(context, group),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Theme.of(context).primaryColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelColor: Colors.grey[600],
                    dividerColor: Colors.transparent,
                    indicatorPadding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_outlined, size: 16),
                            SizedBox(width: 8),
                            Text("EXPENSES"),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 16),
                            SizedBox(width: 8),
                            Text("PEOPLE"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildExpensesTab(service, group),
              _buildParticipantsTab(service, group),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (_tabController.index == 0) {
                if (group.participants.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Add participants first!")),
                  );
                  _tabController.animateTo(1);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(group: group),
                    ),
                  );
                }
              } else {
                _showAddParticipantDialog(context, group);
              }
            },
            label: AnimatedBuilder(
              animation:
                  _tabController.animation ?? const AlwaysStoppedAnimation(0),
              builder: (ctx, child) {
                bool isExpenseTab = _tabController.index == 0;
                return Text(isExpenseTab ? "Add Expense" : "Add Person");
              },
            ),
            icon: AnimatedBuilder(
              animation:
                  _tabController.animation ?? const AlwaysStoppedAnimation(0),
              builder: (ctx, child) {
                bool isExpenseTab = _tabController.index == 0;
                return Icon(
                  isExpenseTab ? Icons.add_shopping_cart : Icons.person_add,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab(GroupService service, Group group) {
    if (group.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No expenses yet",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text("Tap + to add one", style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    double total = group.expenses.fold(0.0, (sum, e) => sum + e.amount);

    // Group expenses by date
    final Map<String, List<Expense>> groupedExpenses = {};
    for (var expense in group.expenses) {
      final dateSlug = DateFormat("yyyyMMdd").format(expense.date);
      if (!groupedExpenses.containsKey(dateSlug)) {
        groupedExpenses[dateSlug] = [];
      }
      groupedExpenses[dateSlug]!.add(expense);
    }
    final sortedKeys = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return Column(
      children: [
        // Fixed Total Spending Card
        Container(
          height: 180, // Fixed height for consistency
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF005041), // Deep Emerald
                Color(0xFF00796B), // Lighter Teal/Green
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF005041).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative Circle
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Spending",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettleUpScreen(group: group),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                "Settle Up",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    "₹${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${group.expenses.length} transactions",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable List
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey<String>('expenses'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sortedKeys.length + 1, // +1 for spacing at bottom
            itemBuilder: (context, index) {
              if (index == sortedKeys.length) {
                return const SizedBox(height: 80); // Bottom padding for FAB
              }

              final dateHook = sortedKeys[index];
              final expensesForDay = groupedExpenses[dateHook] ?? [];
              final date = expensesForDay.first.date;
              final sortedExpenses = expensesForDay.reversed.toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 8,
                    ),
                    child: Text(
                      _formatDateHeader(date),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...sortedExpenses.map((expense) {
                    final payer = group.participants.firstWhere(
                      (p) => p.id == expense.payerId,
                      orElse: () => Participant(id: 'unknown', name: 'Unknown'),
                    );

                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    final isOwner = group.ownerId != null &&
                        currentUserId == group.ownerId;

                    // Debtors = everyone in expense except the payer
                    final debtors = expense.involvedParticipantIds
                        .where((id) => id != expense.payerId)
                        .toList();

                    // Check if any debtor has been marked paid for this expense
                    // We use expense-specific keys: "expId:debtorId_payerId"
                    final anyPaid = debtors.any(
                      (dId) => group.paidSettlementKeys.contains(
                        '${expense.id}:${dId}_${expense.payerId}',
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ExpenseTile(
                        expense: expense,
                        payerName: payer.name,
                        hasPaidMembers: anyPaid,
                        onDelete: () =>
                            service.deleteExpense(group, expense.id),
                        onOwnerLongPress: isOwner
                            ? () => _showExpenseOwnerSheet(
                                context, service, group, expense, debtors)
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailScreen(
                                expense: expense,
                                group: group,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return "TODAY";
    if (dateOnly == yesterday) return "YESTERDAY";
    return DateFormat("MMMM d").format(date).toUpperCase();
  }

  Widget _buildParticipantsTab(GroupService service, Group group) {
    if (group.participants.isEmpty) {
      return const Center(child: Text("No participants yet."));
    }

    return ListView.separated(
      key: const PageStorageKey<String>('people'),
      padding: const EdgeInsets.all(16),
      itemCount: group.participants.length,
      separatorBuilder: (ctx, idx) =>
          Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final person = group.participants[index];
        bool isLast = index == group.participants.length - 1;

        return Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 8,
              ),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(
                person.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: person.hasContactInfo
                  ? Text(
                      person.displayInfo,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    )
                  : null,
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditParticipantDialog(context, group, person);
                  } else if (value == 'delete') {
                    _confirmDeleteParticipant(context, group, person);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit Name'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
            if (isLast) const SizedBox(height: 80), // Padding for FAB
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Owner long-press bottom sheet for per-expense mark-as-paid
  // ─────────────────────────────────────────────────────────────────
  void _showExpenseOwnerSheet(
    BuildContext context,
    GroupService service,
    Group group,
    Expense expense,
    List<String> debtorParticipantIds,
  ) {
    final splitAmount =
        expense.involvedParticipantIds.isNotEmpty
            ? expense.amount / expense.involvedParticipantIds.length
            : expense.amount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ExpenseOwnerSheet(
          expense: expense,
          group: group,
          debtorParticipantIds: debtorParticipantIds,
          splitAmount: splitAmount,
          service: service,
          onDelete: () {
            Navigator.pop(ctx);
            service.deleteExpense(group, expense.id);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Stateful bottom sheet widget so it can rebuild on toggle
// ─────────────────────────────────────────────────────────────────
class _ExpenseOwnerSheet extends StatefulWidget {
  final Expense expense;
  final Group group;
  final List<String> debtorParticipantIds;
  final double splitAmount;
  final GroupService service;
  final VoidCallback onDelete;

  const _ExpenseOwnerSheet({
    required this.expense,
    required this.group,
    required this.debtorParticipantIds,
    required this.splitAmount,
    required this.service,
    required this.onDelete,
  });

  @override
  State<_ExpenseOwnerSheet> createState() => _ExpenseOwnerSheetState();
}

class _ExpenseOwnerSheetState extends State<_ExpenseOwnerSheet> {
  final Set<String> _loading = {};

  String _expenseKey(String debtorId) =>
      '${widget.expense.id}:${debtorId}_${widget.expense.payerId}';

  bool _isPaid(String debtorId) {
    // Prefer live group from service
    final liveGroup = widget.service.groups.firstWhere(
      (g) => g.id == widget.group.id,
      orElse: () => widget.group,
    );
    return liveGroup.paidSettlementKeys.contains(_expenseKey(debtorId));
  }

  Future<void> _toggle(String debtorId) async {
    setState(() => _loading.add(debtorId));
    final key = _expenseKey(debtorId);
    final paid = _isPaid(debtorId);

    if (paid) {
      await widget.service.unmarkAsPaid(
        group: widget.group,
        debtorId: debtorId,
        creditorId: widget.expense.payerId,
        customKey: key,
      );
    } else {
      await widget.service.markAsPaid(
        group: widget.group,
        debtorId: debtorId,
        creditorId: widget.expense.payerId,
        amount: widget.splitAmount,
        customKey: key,
      );
    }

    if (mounted) setState(() => _loading.remove(debtorId));
  }

  @override
  Widget build(BuildContext context) {
    // Listen to GroupService so the sheet rebuilds after toggles
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final payerName = widget.group.participants
            .firstWhere(
              (p) => p.id == widget.expense.payerId,
              orElse: () => Participant(id: '?', name: 'Unknown'),
            )
            .name;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005041).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF005041),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.expense.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Paid by $payerName  •  ₹${widget.expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'WHO HAS PAID THEIR SHARE?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 12),

              // Debtor list
              if (widget.debtorParticipantIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No one owes money for this expense.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              else
                ...widget.debtorParticipantIds.map((dId) {
                  final person = widget.group.participants.firstWhere(
                    (p) => p.id == dId,
                    orElse: () => Participant(id: '?', name: 'Unknown'),
                  );
                  final paid = _isPaid(dId);
                  final loading = _loading.contains(dId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: paid
                          ? Colors.green.withOpacity(0.07)
                          : Theme.of(context).cardTheme.color ??
                              Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: paid
                            ? Colors.green.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.12),
                        width: paid ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: paid
                            ? Colors.green.withOpacity(0.15)
                            : Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: paid
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                        child: Text(
                          person.name.isNotEmpty
                              ? person.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        person.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: paid ? Colors.green[700] : null,
                          decoration:
                              paid ? TextDecoration.none : null,
                        ),
                      ),
                      subtitle: Text(
                        paid
                            ? 'Marked as paid ✓'
                            : 'Owes ₹${widget.splitAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: paid
                              ? Colors.green
                              : Colors.redAccent[200],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _toggle(dId),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: paid
                                      ? Colors.green
                                      : const Color(0xFF005041),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (paid
                                              ? Colors.green
                                              : const Color(0xFF005041))
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      paid
                                          ? Icons.check_rounded
                                          : Icons.payments_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      paid ? 'Paid ✓' : 'Mark Paid',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  );
                }),

              const Divider(height: 28),

              // Delete option
              InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: Colors.red[600], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Delete Expense',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
