import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/participant.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;
  final Group group;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final payerName = group.participants
            .firstWhere((p) => p.id == expense.payerId,
                orElse: () => Participant(id: '?', name: 'Unknown'))
            .name;

    final splitAmount = expense.amount / expense.involvedParticipantIds.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Expense Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Receipt Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    expense.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat.yMMMMd().format(expense.date),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "₹${expense.amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          child: Text(
                            payerName.isNotEmpty ? payerName[0] : '?',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Paid by $payerName",
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
            
            // Split Details
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Split breakdown",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: expense.involvedParticipantIds.map((id) {
                  final person = group.participants.firstWhere(
                    (p) => p.id == id,
                    orElse: () => Participant(id: '?', name: 'Unknown'),
                  );
                  bool isLast = id == expense.involvedParticipantIds.last;
                  
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.secondary,
                          child: Text(person.name.isNotEmpty ? person.name[0] : '?'),
                        ),
                        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          person.id == expense.payerId ? "Already Paid" : "Owes $payerName",
                          style: TextStyle(
                            color: person.id == expense.payerId 
                                ? Colors.green 
                                : Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          "₹${splitAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (!isLast) Divider(height: 1, indent: 70, color: Colors.grey[100]),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
