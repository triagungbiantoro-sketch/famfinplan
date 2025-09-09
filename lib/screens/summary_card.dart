import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';
import 'settings_notifier.dart';

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

  String _currencySymbol = "Rp";
  String _currencyCode = "IDR";

  late VoidCallback _currencyListener;

  @override
  void initState() {
    super.initState();
    _initSettings();
    _loadSummary();
    DatabaseHelper.instance.dataChanged.addListener(_loadSummary);
  }

  @override
  void dispose() {
    DatabaseHelper.instance.dataChanged.removeListener(_loadSummary);
    SettingsNotifier.instance.currentCurrency.removeListener(_currencyListener);
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

  void _initSettings() async {
    await SettingsNotifier.instance.loadSettings();
    _updateCurrency(SettingsNotifier.instance.currentCurrency.value);

    _currencyListener = () {
      _updateCurrency(SettingsNotifier.instance.currentCurrency.value);
    };

    SettingsNotifier.instance.currentCurrency.addListener(_currencyListener);
  }

  void _updateCurrency(String value) {
    if (!mounted) return;
    setState(() {
      _currencyCode = value.split(" ")[0];
      _currencySymbol = value.split(" ")[1].replaceAll("(", "").replaceAll(")", "");
    });
  }

  Future<void> _loadSummary() async {
    final month = widget.selectedMonth;
    final year = widget.selectedYear;

    final summary = await DatabaseHelper.instance.getMonthlySummary(month, year);

    if (!mounted) return;

    setState(() {
      totalIncome = summary['income'] ?? 0.0;
      totalExpense = summary['expense'] ?? 0.0;
    });
  }

  String formatCurrency(double value) {
    final locale = _currencyCode == "IDR" ? "id_ID" : "en_US";
    return NumberFormat.currency(
      locale: locale,
      symbol: _currencySymbol,
      decimalDigits: 0,
    ).format(value);
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

              // Ringkasan isi (tanpa scroll horizontal, pakai Expanded)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    return Expanded(
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatCurrency(amount),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
