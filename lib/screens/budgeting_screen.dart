import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:famfinplan/db/database_helper.dart';
import 'package:famfinplan/screens/settings_notifier.dart';

class BudgetingScreen extends StatefulWidget {
  const BudgetingScreen({super.key});

  @override
  State<BudgetingScreen> createState() => _BudgetingScreenState();
}

class _BudgetingScreenState extends State<BudgetingScreen> {
  final _budgetController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  double _totalBudget = 0;
  double _usedBudget = 0;
  final List<Map<String, dynamic>> _usageList = [];

  DateTime _selectedMonth = DateTime.now();

  String _currencySymbol = "Rp";
  String _currencyCode = "IDR";

  @override
  void initState() {
    super.initState();
    _initSettingsAndLoadBudget();
    DatabaseHelper.instance.dataChanged.addListener(_loadBudget);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    DatabaseHelper.instance.dataChanged.removeListener(_loadBudget);
    super.dispose();
  }

  Future<void> _initSettingsAndLoadBudget() async {
    await SettingsNotifier.instance.loadSettings();
    _updateCurrency(SettingsNotifier.instance.currentCurrency.value);

    SettingsNotifier.instance.currentCurrency.addListener(() {
      _updateCurrency(SettingsNotifier.instance.currentCurrency.value);
    });

    await _loadBudget();
  }

  void _updateCurrency(String value) {
    setState(() {
      _currencyCode = value.split(" ")[0];
      _currencySymbol = value.split(" ")[1].replaceAll("(", "").replaceAll(")", "");
    });
  }

  String _formatCurrency(double value) {
    final locale = _currencyCode == "IDR" ? "id_ID" : "en_US";
    return NumberFormat.currency(
      locale: locale,
      symbol: _currencySymbol,
      decimalDigits: 0,
    ).format(value);
  }

  Future<void> _loadBudget() async {
    final budgetData = await DatabaseHelper.instance.getBudget(month: _selectedMonth);
    setState(() {
      _totalBudget = (budgetData?['totalBudget'] ?? 0).toDouble();
      _usedBudget = (budgetData?['usedBudget'] ?? 0).toDouble();
    });

    final usageData = await DatabaseHelper.instance.getBudgetUsage(month: _selectedMonth);
    setState(() {
      _usageList
        ..clear()
        ..addAll(usageData);
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
    _loadBudget();
  }

  Future<void> _setBudget() async {
    if (_budgetController.text.isEmpty) return;

    final total = double.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0;
    await DatabaseHelper.instance.setBudget(total, month: _selectedMonth);

    setState(() {
      _totalBudget = total;
      _usedBudget = 0;
      _usageList.clear();
    });
    _budgetController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("budget_set", args: [_formatCurrency(total)]))),
    );
  }

  Future<void> _editTotalBudget() async {
    final editController = TextEditingController(text: _totalBudget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("edit_total_budget")),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: tr("monthly_total_budget"),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr("cancel"))),
          ElevatedButton(
            onPressed: () async {
              final newTotal =
                  double.tryParse(editController.text.replaceAll(',', '')) ?? _totalBudget;

              if (newTotal >= _usedBudget) {
                await DatabaseHelper.instance.updateBudgetTotal(newTotal, month: _selectedMonth);
                DatabaseHelper.instance.dataChanged.value =
                    !DatabaseHelper.instance.dataChanged.value;
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr("total_less_than_used"))),
                );
              }
            },
            child: Text(tr("save")),
          ),
        ],
      ),
    );
  }

  Future<void> _addUsage() async {
    if (_amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final note = _noteController.text;

    if (_usedBudget + amount <= _totalBudget) {
      await DatabaseHelper.instance.addBudgetUsage(amount, note, month: _selectedMonth);

      _amountController.clear();
      _noteController.clear();

      await _loadBudget(); // refresh tabel langsung

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("usage_added", args: [_formatCurrency(amount), note]))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("budget_exceeded"))),
      );
    }
  }

  Future<void> _editUsage(Map<String, dynamic> usage) async {
    final amountController = TextEditingController(text: usage['amount'].toString());
    final noteController = TextEditingController(text: usage['note'] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("edit_usage")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: tr("amount"),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: tr("note"),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr("cancel"))),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
              final newNote = noteController.text;
              final diff = newAmount - (usage['amount'] as num).toDouble();

              if (_usedBudget + diff <= _totalBudget) {
                await DatabaseHelper.instance.updateBudgetUsage(
                    usage['id'], newAmount, newNote,
                    month: _selectedMonth);
                await _loadBudget();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr("usage_updated", args: [_formatCurrency(newAmount), newNote]))),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr("budget_exceeded"))),
                );
              }
            },
            child: Text(tr("save")),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUsage(Map<String, dynamic> usage) async {
    await DatabaseHelper.instance.deleteBudgetUsage(usage['id'], month: _selectedMonth);
    await _loadBudget();
  }

  Future<void> _toggleRealized(Map<String, dynamic> usage) async {
    final bool current = (usage['realized'] ?? 0) == 1;
    await DatabaseHelper.instance.updateBudgetUsageRealized(usage['id'], !current, month: _selectedMonth);
    await _loadBudget();
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return Colors.green;
    if (progress < 0.8) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final double remaining = _totalBudget - _usedBudget;
    final double progress =
        _totalBudget > 0 ? (_usedBudget / _totalBudget).clamp(0.0, 1.0).toDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("budget_planning"), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 16, 66, 206),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.arrow_left), onPressed: () => _changeMonth(-1)),
                Text(
                  DateFormat.yMMM().format(_selectedMonth),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.arrow_right), onPressed: () => _changeMonth(1)),
              ],
            ),
            const SizedBox(height: 20),

            // Budget Card
            if (_totalBudget > 0)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.blue.shade50,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr("monthly_budget_summary"),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        color: _getProgressColor(progress),
                        minHeight: 12,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${tr("used")}: ${_formatCurrency(_usedBudget)} | ${tr("remaining")}: ${_formatCurrency(remaining)}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Input total budget + edit
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    decoration: InputDecoration(
                      labelText: tr("monthly_total_budget"),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _setBudget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr("set"),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 5),
                IconButton(
                  onPressed: _editTotalBudget,
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  tooltip: tr("edit"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Add Usage
            if (_totalBudget > 0) ...[
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: tr("usage_amount"),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.money_off),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: tr("note_example"),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.note_alt),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addUsage,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(tr("add_usage"),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            Text(tr("budget_usage_list"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Full Scrollable Usage Table dengan kolom Status + toggle
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.resolveWith((states) => Colors.blueGrey[50]),
                    headingTextStyle:
                        const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    columnSpacing: 20,
                    columns: [
                      DataColumn(label: Text(tr("amount"))),
                      DataColumn(label: Text(tr("note"))),
                      DataColumn(label: Text(tr("status"))), // Kolom status
                      DataColumn(label: Text(tr("action"))),
                    ],
                    rows: _usageList.map((usage) {
                      final bool realized = (usage['realized'] ?? 0) == 1;
                      return DataRow(
                        cells: [
                          DataCell(Text(_formatCurrency((usage['amount'] as num).toDouble()))),
                          DataCell(Text(usage['note'] ?? "")),
                          DataCell(
                            GestureDetector(
                              onTap: () => _toggleRealized(usage),
                              child: Text(
                                realized ? tr("realized") : tr("pending"),
                                style: TextStyle(
                                  color: realized ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Row(
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editUsage(usage)),
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteUsage(usage)),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
