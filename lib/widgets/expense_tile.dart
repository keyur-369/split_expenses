import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final String payerName;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  /// Called when the owner long-presses — shows the owner action sheet.
  /// When null, falls back to the simple delete-only long-press behaviour.
  final VoidCallback? onOwnerLongPress;

  /// Whether this expense has at least one member fully marked as paid
  final bool hasPaidMembers;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.payerName,
    this.onDelete,
    this.onTap,
    this.onOwnerLongPress,
    this.hasPaidMembers = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPaidMembers
              ? Colors.green.withOpacity(0.35)
              : Colors.grey.withOpacity(0.1),
          width: hasPaidMembers ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (onOwnerLongPress != null) {
              // Owner: open rich action sheet
              onOwnerLongPress!();
            } else if (onDelete != null) {
              // Non-owner: simple delete dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Expense?"),
                  content: Text(
                    "Are you sure you want to delete '${expense.title}'?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete!();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon / paid indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasPaidMembers
                        ? Colors.green.withOpacity(0.12)
                        : theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasPaidMembers
                        ? Icons.check_circle_rounded
                        : Icons.receipt_long,
                    color: hasPaidMembers
                        ? Colors.green
                        : theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Paid by $payerName • ${DateFormat.MMMd().format(expense.date)}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "₹${expense.amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF00695C),
                      ),
                    ),
                    if (hasPaidMembers)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Some paid',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
