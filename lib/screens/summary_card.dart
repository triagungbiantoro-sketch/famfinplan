import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';

class SummaryCard extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final Function(int) onMonthChanged;
  final Function(int) onYearChanged;

  const SummaryCard({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  double totalIncome = 0;
  double totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    DatabaseHelper.instance.dataChanged.addListener(_loadSummary);
  }

  @override
  void dispose() {
    DatabaseHelper.instance.dataChanged.removeListener(_loadSummary);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    final month = widget.selectedMonth;
    final year = widget.selectedYear;

    final db = DatabaseHelper.instance;

    final incomeList = await db.getIncomes();
    final expenseList = await db.getExpenses();

    double monthIncome = 0;
    double monthExpense = 0;

    for (var inc in incomeList) {
      final date = DateTime.parse(inc['date']);
      if (date.month == month && date.year == year) {
        monthIncome += (inc['amount'] as num).toDouble();
      }
    }

    for (var exp in expenseList) {
      final date = DateTime.parse(exp['date']);
      if (date.month == month && date.year == year) {
        monthExpense += (exp['amount'] as num).toDouble();
      }
    }

    if (!mounted) return;

    setState(() {
      totalIncome = monthIncome;
      totalExpense = monthExpense;
    });
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: context.locale.languageCode == 'id' ? 'Rp' : '\$',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    double remainingBudget = totalIncome - totalExpense;
    final months = List.generate(12, (index) => index + 1);

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade600,
              Colors.blue.shade900,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter bulan & tahun
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<int>(
                    dropdownColor: Colors.blue.shade900,
                    value: widget.selectedMonth,
                    items: months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                DateFormat("MMMM", context.locale.toString())
                                    .format(DateTime(0, m)),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) widget.onMonthChanged(val);
                    },
                  ),
                  DropdownButton<int>(
                    dropdownColor: Colors.blue.shade900,
                    value: widget.selectedYear,
                    items: List.generate(5, (i) => DateTime.now().year - i)
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text("$y", style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) widget.onYearChanged(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ringkasan isi (scrollable horizontal)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSummaryItem(
                      icon: Icons.arrow_downward,
                      label: tr("income"),
                      amount: totalIncome,
                    ),
                    _buildSummaryItem(
                      icon: Icons.arrow_upward,
                      label: tr("expense"),
                      amount: totalExpense,
                    ),
                    _buildSummaryItem(
                      icon: Icons.account_balance,
                      label: tr("net_balance"),
                      amount: remainingBudget,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required double amount,
  }) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency(amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
