import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/participant.dart';
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

      // Find the payer participant object
      final payerPart = widget.group.participants.firstWhere(
        (p) => p.id == _payerId,
        orElse: () => Participant(id: _payerId!, name: "Unknown Payer"),
      );

      // Find debtor participant objects (involved members who are NOT the payer)
      final debtorParts = widget.group.participants
          .where((p) => _involvedIds.contains(p.id) && p.id != _payerId)
          .toList();

      Navigator.pop(context, {
        'title': title,
        'amount': amount,
        'payer': payerPart,
        'debtors': debtorParts,
      });
    }
  }

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

  Widget _buildPayerSelector(ThemeData theme) {
    if (widget.group.participants.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Who paid?",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C2B4A),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.group.participants.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final p = widget.group.participants[index];
              final isSelected = _payerId == p.id;
              final avatarColor = _getAvatarColor(p.name);

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _payerId = p.id;
                    });
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary
                              : avatarColor.withOpacity(0.85),
                          child: Text(
                            _getInitials(p.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 64,
                        child: Text(
                          p.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : const Color(0xFF5A6A85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvolvedSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "For whom?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C2B4A),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _involvedIds.addAll(
                        widget.group.participants.map((p) => p.id),
                      );
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    "Select All",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _involvedIds.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Select None",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5A6A85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.group.participants.map((p) {
          final isSelected = _involvedIds.contains(p.id);
          final avatarColor = _getAvatarColor(p.name);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.04)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.4)
                      : const Color(0xFFDDE3F0).withOpacity(0.6),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _involvedIds.remove(p.id);
                    } else {
                      _involvedIds.add(p.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: avatarColor.withOpacity(0.15),
                        child: Text(
                          _getInitials(p.name),
                          style: TextStyle(
                            color: avatarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: const Color(0xFF1C2B4A),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : const Color(0xFFDDE3F0),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF), // Match background color of GroupListScreen
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
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: () => Navigator.pop(context),
                color: const Color(0xFF1C2B4A),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add Expense",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C2B4A),
              ),
            ),
            Text(
              "in ${widget.group.name}",
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5A6A85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Unified card for Description and Amount fields
              Container(
                padding: const EdgeInsets.all(16),
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
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: "Description",
                        hintText: "What was this expense for?",
                        prefixIcon: const Icon(Icons.description_outlined),
                        prefixIconColor: theme.colorScheme.primary,
                        floatingLabelStyle: TextStyle(color: theme.colorScheme.primary),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (val) =>
                          val == null || val.isEmpty ? "Enter a description" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "0.00",
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        prefixIconColor: theme.colorScheme.primary,
                        floatingLabelStyle: TextStyle(color: theme.colorScheme.primary),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter amount";
                        if (double.tryParse(val) == null) return "Invalid number";
                        if (double.parse(val) <= 0) return "Amount must be positive";
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Who paid section
              _buildPayerSelector(theme),
              const SizedBox(height: 20),
              // For whom section
              _buildInvolvedSelector(theme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Container(
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
                  color: theme.colorScheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.save_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Save Expense",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

