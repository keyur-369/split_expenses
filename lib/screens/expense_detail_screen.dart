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
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isPaid
                      ? Colors.green.withOpacity(0.15)
                      : Theme.of(ctx).colorScheme.primaryContainer,
                  child: Text(
                    person.name.isNotEmpty
                        ? person.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? Colors.green
                          : Theme.of(ctx).colorScheme.primary,
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaid
                      ? 'Already marked as paid ✓'
                      : 'Owes $payerName for "${widget.expense.title}"',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Amount chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isPaid ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
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
                      'Add a note  (optional)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
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
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Theme.of(ctx)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                      prefixIcon: Icon(
                        Icons.notes_rounded,
                        color: Colors.grey[400],
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
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.25),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
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
                      backgroundColor: isPaid
                          ? Colors.orange.shade700
                          : const Color(0xFF005041),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
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

        final payerName = liveGroup.participants
            .firstWhere(
              (p) => p.id == widget.expense.payerId,
              orElse: () => Participant(id: '?', name: 'Unknown'),
            )
            .name;

        final splitAmount = widget.expense.involvedParticipantIds.isNotEmpty
            ? widget.expense.amount /
                widget.expense.involvedParticipantIds.length
            : widget.expense.amount;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Expense Details',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Receipt Card ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.expense.title,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat.yMMMMd().format(widget.expense.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '₹${widget.expense.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              child: Text(
                                payerName.isNotEmpty ? payerName[0] : '?',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Paid by $payerName',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Section header ────────────────────────────────
                Row(
                  children: [
                    Text(
                      'Split breakdown',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
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
                          color: const Color(0xFF005041).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              size: 13,
                              color: Color(0xFF005041),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Long press to manage',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF005041),
                                fontWeight: FontWeight.w600,
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
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
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
                        statusColor = Colors.green;
                      } else if (paid) {
                        statusText = 'Marked as Paid ✓';
                        statusColor = Colors.green;
                      } else {
                        statusText = 'Owes $payerName';
                        statusColor = Colors.redAccent;
                      }

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
                                              ? Colors.green.withOpacity(0.15)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer,
                                          foregroundColor: paid || isPayer
                                              ? Colors.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .secondary,
                                          child: Text(
                                            person.name.isNotEmpty
                                                ? person.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
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
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
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
                                              color: paid || isPayer
                                                  ? Colors.green[700]
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Amount / loading
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
                                                  ? Colors.green
                                                  : null,
                                              decoration: paid
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              decorationColor: Colors.green,
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
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'PAID',
                                                style: TextStyle(
                                                  color: Colors.white,
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
                                      Icon(
                                        Icons.more_horiz,
                                        color: Colors.grey[400],
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
                                color: Colors.green.withOpacity(0.06),
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
                                    color: Colors.green[500],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      memberNote,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.green[700],
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
                              color: Colors.grey[100],
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
                      color: const Color(0xFF005041).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF005041).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF005041),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Long press any member\'s row to mark their payment. You can also add an optional note visible to everyone.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF005041),
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
