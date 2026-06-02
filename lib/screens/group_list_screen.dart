import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // ── Design tokens (same as LoginScreen / RegisterScreen) ──
  static const Color _primaryColor = Color(0xFF1A73E8);
  static const Color _accentColor = Color(0xFF0D47A1);
  static const Color _bgColor = Color(0xFFF8FAFF);
  static const Color _cardColor = Colors.white;
  static const Color _subtleGray = Color(0xFFF1F4FB);
  static const Color _textDark = Color(0xFF1C2B4A);
  static const Color _textMid = Color(0xFF5A6A85);
  static const Color _errorColor = Color(0xFFE53935);
  static const Color _successColor = Color(0xFF00897B);
  static const Color _borderDefault = Color(0xFFDDE3F0);

  // ── Section palette ──
  static const Color _receiveGreen = Color(0xFF00897B);
  static const Color _receiveGreenBg = Color(0xFFE6F4F1);
  static const Color _oweRed = Color(0xFFE53935);
  static const Color _oweRedBg = Color(0xFFFFEBEB);
  static const Color _settledBg = Color(0xFFF1F4FB);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupService>(context, listen: false).loadGroups();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getUserBalance(Group group, String? uid, GroupService service) {
    if (uid == null) return 0.0;
    final balances = service.getNetBalances(group);
    String? participantId;
    for (var p in group.participants) {
      if (p.userId == uid || p.id == uid) {
        participantId = p.id;
        break;
      }
    }
    if (participantId == null) return 0.0;
    return balances[participantId] ?? 0.0;
  }

  // ─────────────────────────────────────────────
  //  Dialogs
  // ─────────────────────────────────────────────
  void _showAddGroupDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primaryColor, _accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_add_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Group',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 20,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        'Give your group a name',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: _textMid),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Field
              Container(
                decoration: BoxDecoration(
                  color: _subtleGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderDefault, width: 1.2),
                ),
                child: TextField(
                  controller: ctrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(fontSize: 15, color: _textDark),
                  decoration: InputDecoration(
                    hintText: 'e.g., Summer Trip, Flatmates…',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFFB0BAD0)),
                    prefixIcon: const Icon(Icons.group_outlined,
                        size: 20, color: Color(0xFFB0BAD0)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMid,
                        side: const BorderSide(color: _borderDefault),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryColor, _accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (ctrl.text.trim().isNotEmpty) {
                            Provider.of<GroupService>(context, listen: false)
                                .createGroup(ctrl.text.trim());
                            Navigator.of(ctx).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Create',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _oweRedBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.logout_rounded,
                color: _oweRed, size: 26),
          ),
          const SizedBox(height: 16),
          Text('Log Out?',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22, color: _textDark)),
          const SizedBox(height: 8),
          Text(
              'Youll need to sign in again to access your groups.',
          style: GoogleFonts.inter(
          fontSize: 13, color: _textMid, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textMid,
                  side: const BorderSide(color: _borderDefault),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Provider.of<AuthService>(context, listen: false)
                      .signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _oweRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                child: Text('Log Out',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        ],
      ),
    ),
    ),
    );
  }

  void _showDeleteDialog(BuildContext context, GroupService service, Group group,
      {bool settled = false}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _oweRedBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _oweRed, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Delete Group?',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22, color: _textDark)),
              const SizedBox(height: 8),
              Text(
                settled
                    ? "This group is fully settled. Delete '${group.name}' and all its history?"
                    : "Delete '${group.name}' and all its data? This cannot be undone.",
                style: GoogleFonts.inter(
                    fontSize: 13, color: _textMid, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMid,
                        side: const BorderSide(color: _borderDefault),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        service.deleteGroup(group.id);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _oweRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                      child: Text('Delete',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Consumer<GroupService>(
        builder: (context, service, child) {
          final uid = Provider.of<AuthService>(context, listen: false)
              .currentUser
              ?.uid;

          final receivingGroups = <Group>[];
          final sendingGroups = <Group>[];
          final neutralGroups = <Group>[];

          for (final g in service.groups) {
            final bal = _getUserBalance(g, uid, service);
            if (bal > 0.01) {
              receivingGroups.add(g);
            } else if (bal < -0.01) {
              sendingGroups.add(g);
            } else {
              neutralGroups.add(g);
            }
          }

          // Net summary totals
          double totalReceive = 0;
          double totalOwe = 0;
          for (final g in receivingGroups) {
            totalReceive += _getUserBalance(g, uid, service);
          }
          for (final g in sendingGroups) {
            totalOwe += _getUserBalance(g, uid, service).abs();
          }

          int animIdx = 0;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──
              _buildAppBar(context),

              // ── Summary Card ──
              if (!service.isLoading && service.groups.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildSummaryCard(
                      totalReceive, totalOwe, service.groups.length),
                ),

              // ── Loading ──
              if (service.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  ),
                )

              // ── Empty State ──
              else if (service.groups.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context),
                )

              // ── Group Lists ──
              else ...[
                  if (receivingGroups.isNotEmpty) ...[
                    _buildSectionHeader('YOU ARE OWED', _receiveGreen),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildGroupCard(ctx, receivingGroups[i],
                              animIdx++, service, uid),
                          childCount: receivingGroups.length,
                        ),
                      ),
                    ),
                  ],
                  if (sendingGroups.isNotEmpty) ...[
                    _buildSectionHeader('YOU OWE', _oweRed),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildGroupCard(ctx, sendingGroups[i],
                              animIdx++, service, uid),
                          childCount: sendingGroups.length,
                        ),
                      ),
                    ),
                  ],
                  if (neutralGroups.isNotEmpty) ...[
                    _buildSectionHeader(
                      (receivingGroups.isEmpty && sendingGroups.isEmpty)
                          ? 'MY GROUPS'
                          : 'SETTLED',
                      _textMid,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildGroupCard(ctx, neutralGroups[i],
                              animIdx++, service, uid),
                          childCount: neutralGroups.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
            ],
          );
        },
      ),

      // ── FAB ──
      floatingActionButton: _buildFAB(context),
    );
  }

  // ─────────────────────────────────────────────
  //  App Bar
  // ─────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: _bgColor,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 110,
      floating: true,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 14),
        title: Text(
          'My Groups',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 26,
            color: _textDark,
            fontWeight: FontWeight.w400,
          ),
        ),
        background: Container(color: _bgColor),
      ),
      actions: [
        // Profile
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _subtleGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderDefault),
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 20, color: _textMid),
          ),
        ),
        // More menu
        PopupMenuButton<String>(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _subtleGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderDefault),
            ),
            child:
            const Icon(Icons.more_vert_rounded, size: 20, color: _textMid),
          ),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: _cardColor,
          elevation: 4,
          onSelected: (value) {
            if (value == 'logout') _showLogoutDialog(context);
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _oweRedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        size: 16, color: _oweRed),
                  ),
                  const SizedBox(width: 10),
                  Text('Log Out',
                      style: GoogleFonts.inter(
                          color: _oweRed, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Summary Card
  // ─────────────────────────────────────────────
  Widget _buildSummaryCard(
      double totalReceive, double totalOwe, int groupCount) {
    final net = totalReceive - totalOwe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall Balance',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$groupCount group${groupCount == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              net == 0
                  ? 'All settled up!'
                  : net > 0
                  ? '+₹${net.toStringAsFixed(2)}'
                  : '-₹${net.abs().toStringAsFixed(2)}',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 36,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _summaryChip(
                  icon: Icons.arrow_downward_rounded,
                  label: 'You receive',
                  amount: '₹${totalReceive.toStringAsFixed(2)}',
                  color: const Color(0xFF00BFA5),
                ),
                const SizedBox(width: 10),
                _summaryChip(
                  icon: Icons.arrow_upward_rounded,
                  label: 'You owe',
                  amount: '₹${totalOwe.toStringAsFixed(2)}',
                  color: const Color(0xFFFF6B6B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.70))),
                  Text(amount,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Section Header
  // ─────────────────────────────────────────────
  Widget _buildSectionHeader(String title, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Empty State
  // ─────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _subtleGray,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.group_outlined,
                  size: 44, color: Color(0xFFB0BAD0)),
            ),
            const SizedBox(height: 24),
            Text(
              'No groups yet',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 26, color: _textDark),
            ),
            const SizedBox(height: 10),
            Text(
              'Create your first group to start splitting expenses with friends.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: _textMid, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showAddGroupDialog(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text('Create First Group',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Group Card
  // ─────────────────────────────────────────────
  Widget _buildGroupCard(
      BuildContext context,
      Group group,
      int index,
      GroupService service,
      String? uid,
      ) {
    final balance = _getUserBalance(group, uid, service);
    final isReceiving = balance > 0.01;
    final isOwing = balance < -0.01;
    final isSettled = !isReceiving && !isOwing;

    // Colors per state
    final Color avatarBg = isReceiving
        ? _receiveGreenBg
        : isOwing
        ? _oweRedBg
        : _subtleGray;
    final Color avatarText = isReceiving
        ? _receiveGreen
        : isOwing
        ? _oweRed
        : _textMid;
    final Color balanceColor = isReceiving ? _receiveGreen : _oweRed;

    // Staggered entrance
    final double start = (index * 0.08).clamp(0.0, 0.8);
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    final isOwner = group.ownerId == uid;
    final canDeleteSettled =
        service.isGroupSettled(group) && isOwner && group.expenses.isNotEmpty;

    return AnimatedBuilder(
      animation: animation,
      builder: (ctx, child) => Transform.translate(
        offset: Offset(0, 40 * (1 - animation.value)),
        child: Opacity(opacity: animation.value, child: child),
      ),
      child: GestureDetector(
        onLongPress: () => _showDeleteDialog(context, service, group),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderDefault, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A73E8).withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => GroupDetailScreen(group: group)),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ── Avatar ──
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        group.name.isNotEmpty
                            ? group.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 22,
                          color: avatarText,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── Info ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                size: 13, color: Color(0xFFB0BAD0)),
                            const SizedBox(width: 4),
                            Text(
                              '${group.expenses.length} expense${group.expenses.length == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: _textMid),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.people_outline_rounded,
                                size: 13, color: Color(0xFFB0BAD0)),
                            const SizedBox(width: 4),
                            Text(
                              '${group.participants.length} people',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: _textMid),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Balance chip
                        if (!isSettled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isReceiving ? _receiveGreenBg : _oweRedBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isReceiving
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 12,
                                  color: balanceColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isReceiving
                                      ? 'You receive ₹${balance.toStringAsFixed(2)}'
                                      : 'You owe ₹${(-balance).toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: balanceColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 13, color: Color(0xFFB0BAD0)),
                              const SizedBox(width: 4),
                              Text(
                                'Settled up',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFFB0BAD0)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ── Trailing ──
                  canDeleteSettled
                      ? GestureDetector(
                    onTap: () => _showDeleteDialog(
                        context, service, group,
                        settled: true),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _oweRedBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: _oweRed),
                    ),
                  )
                      : Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _subtleGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFFB0BAD0)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  FAB
  // ─────────────────────────────────────────────
  Widget _buildFAB(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.38),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showAddGroupDialog(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'New Group',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}