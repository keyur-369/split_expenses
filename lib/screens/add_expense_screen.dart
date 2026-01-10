import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../services/group_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Group group;
  const AddExpenseScreen({super.key, required this.group});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _payerId;
  final Set<String> _involvedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.group.participants.isNotEmpty) {
      _payerId = widget.group.participants.first.id;
      _involvedIds.addAll(widget.group.participants.map((p) => p.id));
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_involvedIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one person involved")),
        );
        return;
      }

      final title = _titleController.text;
      final amount = double.parse(_amountController.text);

      Provider.of<GroupService>(context, listen: false).addExpense(
        widget.group,
        title,
        amount,
        _payerId!,
        _involvedIds.toList(),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  icon: Icon(Icons.description),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (val) =>
                    val == null || val.isEmpty ? "Enter a description" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  icon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Enter amount";
                  if (double.tryParse(val) == null) return "Invalid number";
                  if (double.parse(val) <= 0) return "Amount must be positive";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "Who paid?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<String>(
                value: _payerId,
                items: widget.group.participants.map((p) {
                  return DropdownMenuItem(value: p.id, child: Text(p.name));
                }).toList(),
                onChanged: (val) => setState(() => _payerId = val),
                decoration: const InputDecoration(icon: Icon(Icons.person)),
              ),
              const SizedBox(height: 24),
              const Text(
                "For whom?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Select All / None link? (Optional, kept simple)
              ...widget.group.participants.map((p) {
                final isSelected = _involvedIds.contains(p.id);
                return CheckboxListTile(
                  title: Text(p.name),
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _involvedIds.add(p.id);
                      } else {
                        _involvedIds.remove(p.id);
                      }
                    });
                  },
                  dense: true,
                );
              }),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("Save Expense"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
