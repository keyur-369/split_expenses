import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/group.dart';
import '../models/participant.dart';
import '../services/group_service.dart';

// Structured settlement data (replaces plain strings)
class SettlementItem {
  final String debtorId;
  final String creditorId;
  final String debtorName;
  final String creditorName;
  final String? creditorUpiId;
  final double amount;
  final String key; // "${debtorId}_${creditorId}"

  SettlementItem({
    required this.debtorId,
    required this.creditorId,
    required this.debtorName,
    required this.creditorName,
    this.creditorUpiId,
    required this.amount,
  }) : key = '${debtorId}_$creditorId';
}

class SettleUpScreen extends StatelessWidget {
  final Group group;
  const SettleUpScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupService>(
      builder: (context, service, _) {
        // Always use fresh group data from service
        final currentGroup = service.groups.firstWhere(
          (g) => g.id == group.id,
          orElse: () => group,
        );

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isOwner = currentGroup.ownerId != null &&
            currentUserId == currentGroup.ownerId;

        final settlements = _buildSettlements(service, currentGroup);
        final balances = service.getNetBalances(currentGroup);

        final paidSettlements =
            settlements.where((s) => currentGroup.paidSettlementKeys.contains(s.key)).toList();
        final pendingSettlements =
            settlements.where((s) => !currentGroup.paidSettlementKeys.contains(s.key)).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Settle Up',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Group summary card ──────────────────────────
                _SummaryHeaderCard(group: currentGroup, balances: balances),
                const SizedBox(height: 24),

                // ── Owner badge ─────────────────────────────────
                if (isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005041).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF005041).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 18,
                          color: Color(0xFF005041),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'You are the group owner — you can mark payments',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF005041),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Pending settlements ─────────────────────────
                if (pendingSettlements.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending Payments',
                    count: pendingSettlements.length,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  ...pendingSettlements.map(
                    (s) => _SettlementCard(
                      settlement: s,
                      isPaid: false,
                      isOwner: isOwner,
                      group: currentGroup,
                      onMarkPaid: () async {
                        await service.markAsPaid(
                          group: currentGroup,
                          debtorId: s.debtorId,
                          creditorId: s.creditorId,
                          amount: s.amount,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${s.debtorName} marked as paid ✓',
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      onUnmark: null,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Settled payments ────────────────────────────
                if (paidSettlements.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.check_circle_rounded,
                    label: 'Settled Payments',
                    count: paidSettlements.length,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  ...paidSettlements.map(
                    (s) => _SettlementCard(
                      settlement: s,
                      isPaid: true,
                      isOwner: isOwner,
                      group: currentGroup,
                      onMarkPaid: null,
                      onUnmark: isOwner
                          ? () async {
                              await service.unmarkAsPaid(
                                group: currentGroup,
                                debtorId: s.debtorId,
                                creditorId: s.creditorId,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${s.debtorName} payment reopened',
                                    ),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── All settled state ───────────────────────────
                if (settlements.isEmpty)
                  _EmptySettledCard(),

                // ── Net Balances breakdown ──────────────────────
                _SectionHeader(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Net Balances',
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 12),
                _BalancesCard(group: currentGroup, balances: balances),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build structured settlements from GroupService data
  List<SettlementItem> _buildSettlements(GroupService service, Group group) {
    final balances = service.getNetBalances(group);

    // Resolve participant name and UPI ID quickly
    final Map<String, Participant> pMap = {};
    for (final p in group.participants) {
      pMap[p.id] = p;
    }
    String nameOf(String id) => pMap[id]?.name ?? 'Unknown';
    String? upiOf(String id) => pMap[id]?.upiId;

    final debtors = <MapEntry<String, double>>[];
    final creditors = <MapEntry<String, double>>[];

    balances.forEach((id, amount) {
      if (amount < -0.01) debtors.add(MapEntry(id, amount));
      if (amount > 0.01) creditors.add(MapEntry(id, amount));
    });

    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final result = <SettlementItem>[];
    int i = 0, j = 0, safety = 0;
    while (i < debtors.length && j < creditors.length) {
      if (safety++ > 1000) break;
      var debtor = debtors[i];
      var creditor = creditors[j];
      final amount = (-debtor.value) < creditor.value
          ? (-debtor.value)
          : creditor.value;
      if (amount < 0.0001) {
        i++;
        j++;
        continue;
      }
      result.add(
        SettlementItem(
          debtorId: debtor.key,
          creditorId: creditor.key,
          debtorName: nameOf(debtor.key),
          creditorName: nameOf(creditor.key),
          creditorUpiId: upiOf(creditor.key),
          amount: amount,
        ),
      );
      debtors[i] = MapEntry(debtor.key, debtor.value + amount);
      creditors[j] = MapEntry(creditor.key, creditor.value - amount);
      if (debtors[i].value.abs() < 0.001) i++;
      if (creditors[j].value < 0.001) j++;
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? count;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryHeaderCard extends StatelessWidget {
  final Group group;
  final Map<String, double> balances;

  const _SummaryHeaderCard({required this.group, required this.balances});

  @override
  Widget build(BuildContext context) {
    final total = group.expenses.fold(0.0, (s, e) => s + e.amount);
    final settled = group.paidSettlementKeys.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF005041), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF005041).withOpacity(0.35),
            blurRadius: 18,
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
                group.name,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (group.ownerId != null &&
                  FirebaseAuth.instance.currentUser?.uid != group.ownerId)
                Builder(builder: (context) {
                  final owner = group.participants.firstWhere(
                    (p) => p.userId == group.ownerId,
                    orElse: () => Participant(id: '?', name: ''),
                  );
                  if (owner.upiId == null || owner.upiId!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () {
                      final Uri uri = Uri.parse(
                        'upi://pay?pa=${owner.upiId}&pn=${Uri.encodeComponent(owner.name)}&cu=INR',
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Pay Owner',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                label: '${group.expenses.length} expenses',
                icon: Icons.receipt_outlined,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: '$settled settled',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: '${group.participants.length} members',
                icon: Icons.people_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatefulWidget {
  final SettlementItem settlement;
  final bool isPaid;
  final bool isOwner;
  final Group group;
  final Future<void> Function()? onMarkPaid;
  final Future<void> Function()? onUnmark;

  const _SettlementCard({
    required this.settlement,
    required this.isPaid,
    required this.isOwner,
    required this.group,
    this.onMarkPaid,
    this.onUnmark,
  });

  @override
  State<_SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends State<_SettlementCard> {
  bool _loading = false;

  Future<void> _payViaUPI(String upiId, double amount, String payeeName) async {
    // UPI URL format: upi://pay?pa=UPI_ID&pn=NAME&am=AMOUNT&cu=INR
    final Uri uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=${amount.toStringAsFixed(2)}&cu=INR',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No UPI app found or cannot launch payment.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isPaid
            ? (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
            : Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isPaid
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ─── Avatar letter ───────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isPaid
                    ? Colors.green.withOpacity(0.15)
                    : Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.isPaid
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.green,
                        size: 24,
                      )
                    : Text(
                        s.debtorName.isNotEmpty
                            ? s.debtorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // ─── Text ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        s.debtorName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration:
                              widget.isPaid ? TextDecoration.none : null,
                          color: widget.isPaid ? Colors.green.shade700 : null,
                        ),
                      ),
                      if (widget.isPaid) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PAID',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'owes ${s.creditorName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (s.creditorUpiId != null &&
                          s.creditorUpiId!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_user_rounded,
                            size: 14, color: Colors.blue.shade300),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${s.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              widget.isPaid ? Colors.green : Colors.red.shade600,
                          decoration:
                              widget.isPaid ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (!widget.isPaid &&
                          (s.creditorUpiId == null ||
                              s.creditorUpiId!.isEmpty))
                        Text(
                          'No UPI set',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Actions ─────────────────────────────────────
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 💳 Pay button (if creditor has UPI ID AND current user IS the debtor)
                if (!widget.isPaid &&
                    s.creditorUpiId != null &&
                    s.creditorUpiId!.isNotEmpty &&
                    FirebaseAuth.instance.currentUser?.uid == s.debtorId)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ActionButton(
                      label: 'Pay',
                      icon: Icons.account_balance_wallet_rounded,
                      color: Colors.blue.shade700,
                      onTap: () => _payViaUPI(
                        s.creditorUpiId!,
                        s.amount,
                        s.creditorName,
                      ),
                    ),
                  ),

                // ─── Owner actions (Mark Paid/Reopen) ────────────────
                if (widget.isOwner)
                  _loading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : widget.isPaid
                          ? _ActionButton(
                              label: 'Reopen',
                              icon: Icons.undo_rounded,
                              color: Colors.orange,
                              onTap: () async {
                                setState(() => _loading = true);
                                if (widget.onUnmark != null) {
                                  await widget.onUnmark!();
                                }
                                if (mounted) setState(() => _loading = false);
                              },
                            )
                          : _ActionButton(
                              label: 'Mark Paid',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF005041),
                              onTap: () async {
                                setState(() => _loading = true);
                                if (widget.onMarkPaid != null) {
                                  await widget.onMarkPaid!();
                                }
                                if (mounted) setState(() => _loading = false);
                              },
                            ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySettledCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 52,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          Text(
            'All settled up! 🎉',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No outstanding debts in this group.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _BalancesCard extends StatelessWidget {
  final Group group;
  final Map<String, double> balances;

  const _BalancesCard({required this.group, required this.balances});

  @override
  Widget build(BuildContext context) {
    if (group.participants.isEmpty) {
      return const Text('No participants.', style: TextStyle(color: Colors.grey));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: group.participants.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          final balance = balances[p.id] ?? 0.0;
          final isPositive = balance >= 0;
          final color = isPositive ? Colors.green : Colors.red;
          final isLast = idx == group.participants.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            isPositive
                                ? 'gets back ₹${balance.toStringAsFixed(2)}'
                                : 'owes ₹${(-balance).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: color.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}₹${balance.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 64,
                  color: Colors.grey.withOpacity(0.15),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
