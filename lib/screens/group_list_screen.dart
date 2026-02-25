import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../models/group.dart';
import 'group_detail_screen.dart';
import 'profile_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
    // Load groups when screen is displayed (e.g., after login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupService>(context, listen: false).loadGroups();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _showAddGroupDialog(BuildContext context) {
    // ... (Existing dialog logic but styled)
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Group"),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: "Group Name",
            hintText: "e.g., Summer Trip",
            prefixIcon: Icon(Icons.group_add_outlined),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                Provider.of<GroupService>(
                  context,
                  listen: false,
                ).createGroup(_controller.text);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Consumer<GroupService>(
        builder: (context, service, child) {
          // Partition groups based on user's net balance
          final currentUid = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

          final receivingGroups = <Group>[];
          final sendingGroups = <Group>[];
          final neutralGroups = <Group>[];

          for (final group in service.groups) {
            final balance = _getUserBalance(group, currentUid, service);
            if (balance > 0.01) {
              receivingGroups.add(group);
            } else if (balance < -0.01) {
              sendingGroups.add(group);
            } else {
              neutralGroups.add(group);
            }
          }

          int animationIndex = 0;

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text("My Groups"),
                centerTitle: false,
                floating: true,
                pinned: true,
                actions: [
                  IconButton(
                    onPressed: () => _showAddGroupDialog(context),
                    icon: const Icon(Icons.add_circle_outline, size: 30),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      } else if (value == 'logout') {
                        _showLogoutDialog(context);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline),
                            SizedBox(width: 8),
                            Text('Profile Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (service.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (service.groups.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "No groups yet",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Create one to start splitting bills!",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => _showAddGroupDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text("Create First Group"),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (receivingGroups.isNotEmpty) ...[
                  _buildSectionHeader("OUTSTANDING RECEIVABLES", Colors.green),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGroupCard(
                          context,
                          receivingGroups[index],
                          animationIndex++,
                          service,
                          currentUid,
                        ),
                        childCount: receivingGroups.length,
                      ),
                    ),
                  ),
                ],
                if (sendingGroups.isNotEmpty) ...[
                  _buildSectionHeader("OUTSTANDING PAYABLES", Colors.red),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGroupCard(
                          context,
                          sendingGroups[index],
                          animationIndex++,
                          service,
                          currentUid,
                        ),
                        childCount: sendingGroups.length,
                      ),
                    ),
                  ),
                ],
                if (neutralGroups.isNotEmpty) ...[
                  _buildSectionHeader(
                    (receivingGroups.isEmpty && sendingGroups.isEmpty)
                        ? "MY GROUPS"
                        : "SETTLED / OTHERS",
                    Colors.grey,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGroupCard(
                          context,
                          neutralGroups[index],
                          animationIndex++,
                          service,
                          currentUid,
                        ),
                        childCount: neutralGroups.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 24, bottom: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getUserBalance(Group group, String? currentUid, GroupService service) {
    if (currentUid == null) return 0.0;
    final balances = service.getNetBalances(group);
    
    // Find the participant ID for the current user
    String? userParticipantId;
    for (var p in group.participants) {
      if (p.userId == currentUid || p.id == currentUid) {
        userParticipantId = p.id;
        break;
      }
    }
    
    if (userParticipantId == null) return 0.0;
    return balances[userParticipantId] ?? 0.0;
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group group,
    int index,
    GroupService service,
    String? currentUid,
  ) {
    final balance = _getUserBalance(group, currentUid, service);
    
    // Staggered animation effect
    final double start = (index * 0.1).clamp(0.0, 1.0);
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
            );
          },
          onLongPress: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Delete Group?"),
                content: Text("Delete '${group.name}' and all its data?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      service.deleteGroup(group.id);
                      Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Delete"),
                  ),
                ],
              ),
            );
          },
          child: Container(
            height: 125,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon / Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${group.expenses.length} expenses • ${group.participants.length} people",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      if (balance.abs() > 0.01) ...[
                        const SizedBox(height: 4),
                        Text(
                          balance > 0 
                              ? "You receive \$${balance.toStringAsFixed(2)}" 
                              : "You owe \$${(-balance).toStringAsFixed(2)}",
                          style: TextStyle(
                            color: balance > 0 ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          "Settled up",
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
