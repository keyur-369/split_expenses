import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

import '../utils/currency_helper.dart';

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

  Map<String, dynamic> _getCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('food') || t.contains('dinner') || t.contains('lunch') ||
        t.contains('breakfast') || t.contains('cafe') || t.contains('coffee') ||
        t.contains('pizza') || t.contains('burger') || t.contains('restaurant') ||
        t.contains('snack') || t.contains('tea')) {
      return {'icon': Icons.restaurant_rounded, 'color': const Color(0xFFFF6D00), 'bg': const Color(0xFFFFE0B2)};
    }
    if (t.contains('uber') || t.contains('cab') || t.contains('taxi') ||
        t.contains('petrol') || t.contains('fuel') || t.contains('auto') ||
        t.contains('bus') || t.contains('train') || t.contains('flight') ||
        t.contains('travel') || t.contains('trip')) {
      return {'icon': Icons.directions_car_rounded, 'color': const Color(0xFF0288D1), 'bg': const Color(0xFFE1F5FE)};
    }
    if (t.contains('rent') || t.contains('flat') || t.contains('wifi') ||
        t.contains('internet') || t.contains('light') || t.contains('electricity') ||
        t.contains('bill') || t.contains('maid') || t.contains('maintenance')) {
      return {'icon': Icons.home_rounded, 'color': const Color(0xFF7B1FA2), 'bg': const Color(0xFFF3E5F5)};
    }
    if (t.contains('movie') || t.contains('cinema') || t.contains('party') ||
        t.contains('drink') || t.contains('beer') || t.contains('club') ||
        t.contains('game') || t.contains('show') || t.contains('event')) {
      return {'icon': Icons.local_activity_rounded, 'color': const Color(0xFFC2185B), 'bg': const Color(0xFFFCE4EC)};
    }
    if (t.contains('grocery') || t.contains('groceries') || t.contains('supermarket') ||
        t.contains('mart') || t.contains('vegetable') || t.contains('fruit') ||
        t.contains('milk') || t.contains('store')) {
      return {'icon': Icons.shopping_cart_rounded, 'color': const Color(0xFF00897B), 'bg': const Color(0xFFE0F2F1)};
    }
    if (t.contains('shop') || t.contains('clothes') || t.contains('shoes') ||
        t.contains('amazon') || t.contains('flipkart') || t.contains('mall')) {
      return {'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFF3F51B5), 'bg': const Color(0xFFE8EAF6)};
    }
    if (t.contains('health') || t.contains('doc') || t.contains('doctor') ||
        t.contains('medicine') || t.contains('pharmacy') || t.contains('gym')) {
      return {'icon': Icons.medical_services_rounded, 'color': const Color(0xFFD32F2F), 'bg': const Color(0xFFFFEBEE)};
    }
    return {'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF1A73E8), 'bg': const Color(0xFFEBF3FF)};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _getCategory(expense.title);
    final IconData categoryIcon = category['icon'] as IconData;
    final Color categoryColor = category['color'] as Color;
    final Color categoryBg = category['bg'] as Color;

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
                    color: hasPaidMembers ? Colors.green.withOpacity(0.12) : categoryBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasPaidMembers ? Icons.check_circle_rounded : categoryIcon,
                    color: hasPaidMembers ? Colors.green : categoryColor,
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
                      CurrencyHelper.format(expense.amount, currencyCode: expense.currencyCode),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.primary,
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
