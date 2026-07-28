import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../models/group.dart';
import '../models/expense.dart';
import '../models/participant.dart';
import '../services/group_service.dart';
import '../utils/currency_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  final Group? group;

  const AnalyticsScreen({super.key, this.group});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  static const Color _primaryColor = Color(0xFF1A73E8);
  static const Color _accentColor = Color(0xFF0D47A1);
  static const Color _bgColor = Color(0xFFF8FAFF);
  static const Color _cardColor = Colors.white;
  static const Color _textDark = Color(0xFF1C2B4A);
  static const Color _textMid = Color(0xFF5A6A85);

  final Map<String, Color> _categoryColors = {
    'Food': const Color(0xFFFF6B6B),
    'Travel': const Color(0xFF4ECDC4),
    'Bills': const Color(0xFFFFD166),
    'Shopping': const Color(0xFF118AB2),
    'Groceries': const Color(0xFF06D6A0),
    'Entertainment': const Color(0xFF9D4EDD),
    'General': const Color(0xFF5A6A85),
  };

  final Map<String, IconData> _categoryIcons = {
    'Food': Icons.fastfood_rounded,
    'Travel': Icons.flight_takeoff_rounded,
    'Bills': Icons.receipt_long_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Groceries': Icons.local_grocery_store_rounded,
    'Entertainment': Icons.movie_creation_rounded,
    'General': Icons.payments_rounded,
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Map<String, double> _getCategoryTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (var exp in expenses) {
      final cat = exp.category.isEmpty ? 'General' : exp.category;
      totals[cat] = (totals[cat] ?? 0.0) + exp.amount;
    }
    return totals;
  }

  Map<String, double> _getSpenderTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (var exp in expenses) {
      totals[exp.payerId] = (totals[exp.payerId] ?? 0.0) + exp.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final List<Expense> expenses;
    final List<Participant> participants;
    final String currencyCode;
    final String title;

    if (widget.group != null) {
      expenses = widget.group!.expenses;
      participants = widget.group!.participants;
      currencyCode = widget.group!.currencyCode;
      title = '${widget.group!.name} Analytics';
    } else {
      final allGroups = Provider.of<GroupService>(context).groups;
      expenses = allGroups.expand((g) => g.expenses).toList();
      participants = allGroups.expand((g) => g.participants).toList();
      currencyCode = 'INR';
      title = 'Overall Analytics & Insights';
    }

    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final categoryTotals = _getCategoryTotals(expenses);
    final spenderTotals = _getSpenderTotals(expenses);

    // Top Spender
    String topSpenderName = 'N/A';
    double topSpenderAmount = 0.0;
    if (spenderTotals.isNotEmpty) {
      final topEntry = spenderTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      topSpenderAmount = topEntry.value;
      final foundParticipant = participants.firstWhere(
        (p) => p.id == topEntry.key || p.userId == topEntry.key,
        orElse: () => Participant(id: topEntry.key, name: 'Member'),
      );
      topSpenderName = foundParticipant.name;
    }

    // Highest Expense
    Expense? highestExp;
    if (expenses.isNotEmpty) {
      highestExp = expenses.reduce((a, b) => a.amount > b.amount ? a : b);
    }

    final avgPerPerson = participants.isNotEmpty
        ? totalSpent / participants.length
        : 0.0;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.outfit(
            color: _textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
      ),
      body: expenses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 72, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Expense Data Yet',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add expenses to groups to view category breakdowns, spending trends, and top spender insights.',
                      style: GoogleFonts.inter(fontSize: 14, color: _textMid),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Key Metrics Cards Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      _buildMetricCard(
                        'Total Spend',
                        CurrencyHelper.format(totalSpent, currencyCode: currencyCode),
                        Icons.account_balance_wallet_rounded,
                        const LinearGradient(colors: [_primaryColor, _accentColor]),
                      ),
                      _buildMetricCard(
                        'Avg Per Person',
                        CurrencyHelper.format(avgPerPerson, currencyCode: currencyCode),
                        Icons.groups_rounded,
                        const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF004D40)]),
                      ),
                      _buildMetricCard(
                        'Top Spender',
                        topSpenderName,
                        Icons.workspace_premium_rounded,
                        const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
                        subtitle: CurrencyHelper.format(topSpenderAmount, currencyCode: currencyCode),
                      ),
                      _buildMetricCard(
                        'Highest Expense',
                        highestExp != null ? highestExp.title : 'None',
                        Icons.trending_up_rounded,
                        const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)]),
                        subtitle: highestExp != null
                            ? CurrencyHelper.format(highestExp.amount, currencyCode: currencyCode)
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Category Donut Chart Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Breakdown',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            // Animated Donut Chart
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: DonutChartPainter(
                                      categoryTotals: categoryTotals,
                                      totalSpent: totalSpent,
                                      colors: _categoryColors,
                                      progress: _animController.value,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${categoryTotals.length}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: _textDark,
                                            ),
                                          ),
                                          Text(
                                            'Categories',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: _textMid,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Categories List Legend
                            Expanded(
                              child: Column(
                                children: categoryTotals.entries.map((entry) {
                                  final cat = entry.key;
                                  final val = entry.value;
                                  final pct = totalSpent > 0 ? (val / totalSpent * 100) : 0.0;
                                  final color = _categoryColors[cat] ?? const Color(0xFF1A73E8);
                                  final icon = _categoryIcons[cat] ?? Icons.category_rounded;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(icon, size: 14, color: color),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            cat,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _textDark,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${pct.toStringAsFixed(1)}%',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _textMid,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Category Breakdown Detail Cards
                  Text(
                    'Category Details',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...categoryTotals.entries.map((entry) {
                    final cat = entry.key;
                    final amt = entry.value;
                    final pct = totalSpent > 0 ? (amt / totalSpent) : 0.0;
                    final color = _categoryColors[cat] ?? _primaryColor;
                    final icon = _categoryIcons[cat] ?? Icons.category_rounded;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEBF0F8), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _textDark,
                                      ),
                                    ),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(1)}% of total expenses',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _textMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyHelper.format(amt, currencyCode: currencyCode),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: const Color(0xFFF1F4FB),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Gradient gradient, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom Donut Chart Painter
class DonutChartPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final double totalSpent;
  final Map<String, Color> colors;
  final double progress;

  DonutChartPainter({
    required this.categoryTotals,
    required this.totalSpent,
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSpent <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    for (final entry in categoryTotals.entries) {
      final sweepAngle = (entry.value / totalSpent) * (2 * math.pi) * progress;
      paint.color = colors[entry.key] ?? const Color(0xFF1A73E8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.05, // Small gap between segments
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.totalSpent != totalSpent;
  }
}
