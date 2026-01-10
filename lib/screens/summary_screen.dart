import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../services/group_service.dart';

class SummaryScreen extends StatelessWidget {
  final Group group;
  const SummaryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // Watch service for updates if expenses change elsewhere, though typically we just view this.
    final service = Provider.of<GroupService>(context);
    final settlements = service.getSettlements(group);
    final balances = service.getNetBalances(group);

    return Scaffold(
      appBar: AppBar(title: const Text("Balances & Settlement")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How to settle up:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),
            if (settlements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "Everyone is settled up! \nNo debts.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              ...settlements.map(
                (s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.monetization_on,
                      color: Colors.green,
                    ),
                    title: Text(
                      s,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

            const Divider(height: 48, thickness: 2),

            const Text(
              "Net Balances:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "(Positive = Owed to them, Negative = They owe)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (group.participants.isEmpty)
              const Text("No participants.")
            else
              ...group.participants.map((p) {
                final balance = balances[p.id] ?? 0.0;
                final isPositive = balance >= 0;
                final color = isPositive ? Colors.green : Colors.red;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  trailing: Text(
                    "${isPositive ? '+' : ''}₹${balance.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
