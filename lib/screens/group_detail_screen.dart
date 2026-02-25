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
import 'add_expense_screen.dart';
import 'summary_screen.dart';
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
              // Delete logic
              Provider.of<GroupService>(
                context,
                listen: false,
              ).deleteGroup(group.id);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Go back to Group List
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
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
                          builder: (_) => SummaryScreen(group: group),
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
                              builder: (_) => SummaryScreen(group: group),
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ExpenseTile(
                        expense: expense,
                        payerName: payer.name,
                        onDelete: () =>
                            service.deleteExpense(group, expense.id),
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
}
