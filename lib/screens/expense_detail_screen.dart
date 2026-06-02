import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/participant.dart';
import '../services/group_service.dart';
import '../widgets/upi_payment_sheet.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;
  final Group group;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.group,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final Set<String> _loadingIds = {};

  Color _getAvatarColor(String name) {
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final colors = [
      const Color(0xFF00796B), // Teal
      const Color(0xFF1976D2), // Blue
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFF388E3C), // Green
      const Color(0xFFD32F2F), // Red
      const Color(0xFFF57C00), // Orange
      const Color(0xFFC2185B), // Pink
      const Color(0xFF5D4037), // Brown
    ];
    return colors[hash % colors.length];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "";
    final parts = name.trim().split(" ");
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Returns the current user's participant record if they are
  /// a debtor (i.e. not the payer) in this expense.
  Participant? _currentUserDebtor(Group liveGroup, String? currentUserId) {
    if (currentUserId == null) return null;
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    for (final p in liveGroup.participants) {
      final isMe = p.userId == currentUserId ||
          p.id == currentUserId ||
          (currentUserEmail != null &&
              p.email != null &&
              p.email!.isNotEmpty &&
              p.email!.toLowerCase() == currentUserEmail.toLowerCase());
      if (isMe &&
          p.id != widget.expense.payerId &&
          widget.expense.involvedParticipantIds.contains(p.id)) {
        return p;
      }
    }
    return null;
  }

  /// Sticky bottom pay bar — visible when the current user owes money
  /// and the payer has a UPI ID configured.
  Widget _buildPayBar({
    required String upiId,
    required String payeeName,
    required double amount,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFDDE3F0).withOpacity(0.6),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              Color.fromARGB(
                theme.colorScheme.primary.alpha,
                (theme.colorScheme.primary.red * 0.95).round(),
                (theme.colorScheme.primary.green * 1.05).clamp(0, 255).round(),
                (theme.colorScheme.primary.blue * 1.1).clamp(0, 255).round(),
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => showUpiPaymentSheet(
            context,
            upiId: upiId,
            payeeName: payeeName,
            amount: amount,
            description: 'Payment for “${widget.expense.title}”',
          ),
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.white),
          label: Text(
            'Pay ₹${amount.toStringAsFixed(2)} Now',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _payViaUPI(String upiId, double amount, String payeeName) async {
    if (!mounted) return;
    await showUpiPaymentSheet(
      context,
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      description: 'Payment for ${widget.expense.title}',
    );
  }

  // Expense-scoped key: "expenseId:debtorId_payerId"
  String _key(String debtorId) =>
      '${widget.expense.id}:${debtorId}_${widget.expense.payerId}';

  bool _isPaid(Group liveGroup, String debtorId) =>
      liveGroup.paidSettlementKeys.contains(_key(debtorId));

  String? _note(Group liveGroup, String debtorId) =>
      liveGroup.paidSettlementNotes[_key(debtorId)];

  bool _isDebtor(String participantId) =>
      participantId != widget.expense.payerId;

  Future<void> _togglePaid(
    BuildContext context,
    GroupService service,
    Group liveGroup,
    String debtorId,
    double splitAmount, {
    String? note,
  }) async {
    setState(() => _loadingIds.add(debtorId));
    final paid = _isPaid(liveGroup, debtorId);
    final key = _key(debtorId);

    if (paid) {
      await service.unmarkAsPaid(
        group: liveGroup,
        debtorId: debtorId,
        creditorId: widget.expense.payerId,
        customKey: key,
      );
    } else {
      await service.markAsPaid(
        group: liveGroup,
        debtorId: debtorId,
        creditorId: widget.expense.payerId,
        amount: splitAmount,
        customKey: key,
        note: note,
      );
    }

    if (mounted) setState(() => _loadingIds.remove(debtorId));
  }

  void _showMarkPaidSheet(
    BuildContext context,
    GroupService service,
    Group liveGroup,
    Participant person,
    double splitAmount,
  ) {
    final isPaid = _isPaid(liveGroup, person.id);
    final existingNote = _note(liveGroup, person.id);

    final payerName = liveGroup.participants
        .firstWhere(
          (p) => p.id == widget.expense.payerId,
          orElse: () => Participant(id: '?', name: 'Unknown'),
        )
        .name;

    // Note controller — pre-fill if already paid with a note
    final noteController = TextEditingController(
      text: isPaid ? (existingNote ?? '') : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE3F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isPaid
                      ? Colors.green.withOpacity(0.12)
                      : _getAvatarColor(person.name).withOpacity(0.15),
                  child: Text(
                    _getInitials(person.name),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? Colors.green
                          : _getAvatarColor(person.name),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  person.name,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1C2B4A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaid
                      ? 'Already marked as paid ✓'
                      : 'Owes $payerName for "${widget.expense.title}"',
                  style: const TextStyle(color: Color(0xFF5A6A85), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Amount chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isPaid ? Colors.green : Colors.red).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: (isPaid ? Colors.green : Colors.red).withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isPaid
                        ? '₹${splitAmount.toStringAsFixed(2)} — Paid'
                        : '₹${splitAmount.toStringAsFixed(2)} outstanding',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isPaid ? Colors.green : Colors.red.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Note field (only for "mark as paid" action) ────────
                if (!isPaid) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add a note (optional)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1C2B4A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. "Paid cash at restaurant" or "Received via UPI"',
                      hintStyle: const TextStyle(
                        color: Color(0xFF5A6A85),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFFDDE3F0).withOpacity(0.8),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFFDDE3F0).withOpacity(0.8),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Theme.of(ctx).colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      counterStyle: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5A6A85),
                      ),
                      prefixIcon: const Icon(
                        Icons.notes_rounded,
                        color: Color(0xFF5A6A85),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Show existing note when already paid ───────────────
                if (isPaid && existingNote != null && existingNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            existingNote,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.green[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isPaid
                        ? null
                        : LinearGradient(
                            colors: [
                              Theme.of(ctx).colorScheme.primary,
                              Color.fromARGB(
                                Theme.of(ctx).colorScheme.primary.alpha,
                                (Theme.of(ctx).colorScheme.primary.red * 0.95).round(),
                                (Theme.of(ctx).colorScheme.primary.green * 1.05).clamp(0, 255).round(),
                                (Theme.of(ctx).colorScheme.primary.blue * 1.1).clamp(0, 255).round(),
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isPaid ? Colors.orange.shade700 : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: (isPaid ? Colors.orange.shade700 : Theme.of(ctx).colorScheme.primary)
                            .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final note = noteController.text.trim();
                      Navigator.pop(ctx);
                      await _togglePaid(
                        context,
                        service,
                        liveGroup,
                        person.id,
                        splitAmount,
                        note: isPaid ? null : (note.isEmpty ? null : note),
                      );
                    },
                    icon: Icon(
                      isPaid
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline,
                      color: Colors.white,
                    ),
                    label: Text(
                      isPaid ? 'Unmark as Paid' : 'Mark as Paid',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF5A6A85), fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupService>(
      builder: (context, service, _) {
        final liveGroup = service.groups.firstWhere(
          (g) => g.id == widget.group.id,
          orElse: () => widget.group,
        );

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isOwner =
            liveGroup.ownerId != null && currentUserId == liveGroup.ownerId;

        final payerParticipant = liveGroup.participants.firstWhere(
          (p) => p.id == widget.expense.payerId,
          orElse: () => Participant(id: '?', name: 'Unknown'),
        );
        final payerName = payerParticipant.name;
        final payerUpiId = payerParticipant.upiId;

        final splitAmount = widget.expense.involvedParticipantIds.isNotEmpty
            ? widget.expense.amount /
                widget.expense.involvedParticipantIds.length
            : widget.expense.amount;

        // Determine if current user should see the Pay Now button
        final debtorParticipant = _currentUserDebtor(liveGroup, currentUserId);
        final isCurrentUserAlreadyPaid =
            debtorParticipant != null && _isPaid(liveGroup, debtorParticipant.id);
        final showPayBar = debtorParticipant != null &&
            !isCurrentUserAlreadyPaid &&
            payerUpiId != null &&
            payerUpiId.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFF),
          appBar: AppBar(
            leadingWidth: 56,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDDE3F0).withOpacity(0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(0xFF1C2B4A),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            title: Text(
              'Expense Details',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C2B4A),
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          bottomNavigationBar: showPayBar
              ? _buildPayBar(
                  upiId: payerUpiId,
                  payeeName: payerName,
                  amount: splitAmount,
                )
              : null,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24, 16, 24,
              showPayBar ? 8 : 24, // extra bottom room when bar visible
            ),
            child: Column(
              children: [
                // ── Receipt Card ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFDDE3F0).withOpacity(0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.015),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.expense.title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1C2B4A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat.yMMMMd().format(widget.expense.date),
                        style: const TextStyle(
                          color: Color(0xFF5A6A85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '₹${widget.expense.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C2B4A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getAvatarColor(payerName).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getAvatarColor(payerName).withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: _getAvatarColor(payerName),
                              foregroundColor: Colors.white,
                              child: Text(
                                _getInitials(payerName),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Paid by $payerName',
                              style: TextStyle(
                                color: _getAvatarColor(payerName),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section header ────────────────────────────────
                Row(
                  children: [
                    Text(
                      'Split breakdown',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C2B4A),
                      ),
                    ),
                    const Spacer(),
                    if (isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF1A73E8).withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              size: 13,
                              color: Color(0xFF1A73E8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Long press to manage',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF1A73E8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Member rows ───────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFDDE3F0).withOpacity(0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.015),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: widget.expense.involvedParticipantIds
                        .asMap()
                        .entries
                        .map((entry) {
                      final idx = entry.key;
                      final id = entry.value;

                      final person = liveGroup.participants.firstWhere(
                        (p) => p.id == id,
                        orElse: () => Participant(id: '?', name: 'Unknown'),
                      );

                      final isPayer = id == widget.expense.payerId;
                      final isDebtor = _isDebtor(id);
                      final paid = !isPayer && _isPaid(liveGroup, id);
                      final memberNote =
                          !isPayer ? _note(liveGroup, id) : null;
                      final loading = _loadingIds.contains(id);

                      final isLast = idx ==
                          widget.expense.involvedParticipantIds.length - 1;

                      // Status label + colour
                      final String statusText;
                      final Color statusColor;
                      if (isPayer) {
                        statusText = 'Already Paid';
                        statusColor = Colors.green.shade700;
                      } else if (paid) {
                        statusText = 'Marked as Paid ✓';
                        statusColor = Colors.green.shade700;
                      } else {
                        statusText = 'Owes $payerName';
                        statusColor = Colors.redAccent.shade700;
                      }

                      final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
                      final isMe = person.userId == currentUserId ||
                          person.id == currentUserId ||
                          (currentUserEmail != null &&
                              person.email != null &&
                              person.email!.isNotEmpty &&
                              person.email!.toLowerCase() == currentUserEmail.toLowerCase());

                      final topRadius = idx == 0 ? 20.0 : 0.0;
                      final bottomRadius = isLast ? 20.0 : 0.0;

                      return Column(
                        children: [
                          // ── Member tile ───────────────────────
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(topRadius),
                              topRight: Radius.circular(topRadius),
                              bottomLeft: Radius.circular(
                                memberNote == null || memberNote.isEmpty
                                    ? bottomRadius
                                    : 0,
                              ),
                              bottomRight: Radius.circular(
                                memberNote == null || memberNote.isEmpty
                                    ? bottomRadius
                                    : 0,
                              ),
                            ),
                            child: InkWell(
                              onLongPress: isOwner && isDebtor
                                  ? () {
                                      HapticFeedback.mediumImpact();
                                      _showMarkPaidSheet(
                                        context,
                                        service,
                                        liveGroup,
                                        person,
                                        splitAmount,
                                      );
                                    }
                                  : null,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(topRadius),
                                topRight: Radius.circular(topRadius),
                                bottomLeft: Radius.circular(
                                  memberNote == null || memberNote.isEmpty
                                      ? bottomRadius
                                      : 0,
                                ),
                                bottomRight: Radius.circular(
                                  memberNote == null || memberNote.isEmpty
                                      ? bottomRadius
                                      : 0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    // Avatar with optional check badge
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: paid || isPayer
                                              ? Colors.green.withOpacity(0.12)
                                              : _getAvatarColor(person.name).withOpacity(0.15),
                                          foregroundColor: paid || isPayer
                                              ? Colors.green
                                              : _getAvatarColor(person.name),
                                          child: Text(
                                            _getInitials(person.name),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (paid || isPayer)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade600,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person.name,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: const Color(0xFF1C2B4A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Pay button / Amount / loading
                                    if (!isPayer &&
                                        !paid &&
                                        isMe &&
                                        payerUpiId != null &&
                                        payerUpiId.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue.shade700,
                                                Colors.blue.shade800,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.shade700.withOpacity(0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () => _payViaUPI(
                                              payerUpiId,
                                              splitAmount,
                                              payerName,
                                            ),
                                            icon: const Icon(Icons.account_balance_wallet_rounded,
                                                size: 12, color: Colors.white),
                                            label: const Text(
                                              'Pay',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (loading)
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    else
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${splitAmount.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: paid || isPayer
                                                  ? Colors.green.shade700
                                                  : const Color(0xFF1C2B4A),
                                              decoration: paid
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              decorationColor: Colors.green.shade700,
                                            ),
                                          ),
                                          if (paid)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.green.shade300,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                'PAID',
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                    if (isOwner && isDebtor && !loading) ...[
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.more_horiz,
                                        color: Color(0xFF5A6A85),
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── Payment note bubble ───────────────
                          if (memberNote != null && memberNote.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.04),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(bottomRadius),
                                  bottomRight: Radius.circular(bottomRadius),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(width: 58), // align with name
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 13,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      memberNote,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.green.shade800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 70,
                              color: const Color(0xFFDDE3F0).withOpacity(0.6),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Owner hint banner ─────────────────────────────
                if (isOwner)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1A73E8).withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF1A73E8),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Long press any member\'s row to mark their payment. You can also add an optional note visible to everyone.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF1A73E8),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
