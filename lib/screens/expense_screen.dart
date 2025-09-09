import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';
import 'settings_notifier.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedDate;

  List<Map<String, dynamic>> _expenseList = [];
  final List<String> _categories = ["food", "transport", "shopping", "bills", "other"];
  final Map<String, Color> _categoryColors = {
    "food": Colors.orange.shade700,
    "transport": Colors.blue.shade700,
    "shopping": Colors.green.shade700,
    "bills": Colors.purple.shade700,
    "other": Colors.grey.shade600,
  };

  // Currency
  String _currencySymbol = "Rp";
  String _currencyCode = "IDR";

  // Filter per bulan
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadExpenses();
    _selectedDate = DateTime.now();
  }

  void _loadSettings() {
    SettingsNotifier.instance.currentCurrency.addListener(() {
      final value = SettingsNotifier.instance.currentCurrency.value;
      final parts = value.split(" ");
      setState(() {
        _currencyCode = parts[0];
        _currencySymbol =
            parts.length > 1 ? parts[1].replaceAll("(", "").replaceAll(")", "") : _currencyCode;
      });
    });
  }

  Future<void> _loadExpenses() async {
    final data = await DatabaseHelper.instance.getExpenses();
    setState(() {
      _expenseList = data;
    });
  }

  double get _totalExpenseThisMonth {
    return _filteredExpenseList.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  List<Map<String, dynamic>> get _filteredExpenseList {
    return _expenseList.where((expense) {
      final date = DateTime.parse(expense["date"]);
      return date.month == _selectedMonth && date.year == _selectedYear;
    }).toList();
  }

  String _formatCurrency(double value) {
    final locale = _currencyCode == "IDR" ? "id_ID" : "en_US";
    final decimalDigits = _currencyCode == "IDR" ? 0 : 2;
    return NumberFormat.currency(
      locale: locale,
      symbol: _currencySymbol,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  double _parseCurrency(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null || _selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("complete_category_date"))),
        );
        return;
      }

      final amount = _parseCurrency(_amountController.text);
      final note = _noteController.text;

      await DatabaseHelper.instance.insertExpense({
        "amount": amount,
        "category": _selectedCategory!,
        "note": note,
        "date": _selectedDate!.toIso8601String(),
      });

      _amountController.clear();
      _noteController.clear();
      _selectedCategory = null;
      _selectedDate = DateTime.now();

      _loadExpenses();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr("expense_saved",
                args: [_formatCurrency(amount), tr(_selectedCategory ?? "other")]))),
      );
    }
  }

  Future<void> _deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    _loadExpenses();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("data_deleted"))),
    );
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    final editAmountController =
        TextEditingController(text: _formatCurrency((expense["amount"] as num).toDouble()));
    final editNoteController = TextEditingController(text: expense["note"] ?? "");
    String? editCategory = expense["category"];
    DateTime editDate = DateTime.parse(expense["date"]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("edit_expense")),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildFancyTextField(
                controller: editAmountController,
                label: tr("amount"),
                icon: Icons.money_off,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildFancyDropdown(
                label: tr("category"),
                value: editCategory,
                items: _categories,
                onChanged: (val) => editCategory = val,
                icon: Icons.category,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: editDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => editDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr("date"),
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(DateFormat("dd/MM/yyyy", context.locale.toString()).format(editDate)),
                ),
              ),
              const SizedBox(height: 12),
              _buildFancyTextField(
                controller: editNoteController,
                label: tr("note"),
                icon: Icons.note_alt,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(tr("cancel")),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(tr("save"), style: const TextStyle(color: Colors.white)),
            onPressed: () async {
              final updatedAmount = _parseCurrency(editAmountController.text);
              await DatabaseHelper.instance.updateExpense(expense["id"], {
                "amount": updatedAmount,
                "category": editCategory ?? "other",
                "note": editNoteController.text,
                "date": editDate.toIso8601String(),
              });
              Navigator.pop(context);
              _loadExpenses();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr("data_updated"))),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFancyTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) =>
          value == null || value.isEmpty ? "${tr("enter")} $label" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildFancyDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((cat) => DropdownMenuItem(value: cat, child: Text(tr(cat)))).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? "${tr("choose")} $label" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFancyTextField(
                    controller: _amountController,
                    label: tr("amount"),
                    icon: Icons.money_off,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _buildFancyDropdown(
                    label: tr("category"),
                    value: _selectedCategory,
                    items: _categories,
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    icon: Icons.category,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr("date"),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(DateFormat("dd/MM/yyyy", context.locale.toString())
                          .format(_selectedDate!)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFancyTextField(
                    controller: _noteController,
                    label: tr("note"),
                    icon: Icons.note_alt,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _saveExpense();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(tr("save"), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text(tr("expense"), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Total pengeluaran bulan ini
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.red.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.money_off, size: 28, color: Colors.red),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr("total_expense_this_month"),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(_formatCurrency(_totalExpenseThisMonth),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Dropdown filter bulan & tahun
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    items: List.generate(12, (i) {
                      final month = i + 1;
                      return DropdownMenuItem(
                          value: month, child: Text(DateFormat.MMMM().format(DateTime(0, month))));
                    }),
                    onChanged: (val) => setState(() => _selectedMonth = val ?? _selectedMonth),
                    decoration: const InputDecoration(
                      labelText: "Month",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    items: List.generate(10, (i) => DateTime.now().year - 5 + i)
                        .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedYear = val ?? _selectedYear),
                    decoration: const InputDecoration(
                      labelText: "Year",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredExpenseList.isEmpty
                ? Center(child: Text(tr("no_data")))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredExpenseList.length,
                    itemBuilder: (context, index) {
                      final expense = _filteredExpenseList[index];
                      final color = _categoryColors[expense["category"]] ?? Colors.grey;
                      final date = DateTime.parse(expense["date"]);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(Icons.money_off, color: color, size: 20),
                          ),
                          title: Text(
                            _formatCurrency((expense["amount"] as num).toDouble()),
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.grey.shade900, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(expense["category"]),
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                              Text(DateFormat("dd/MM/yyyy", context.locale.toString()).format(date),
                                  style: const TextStyle(fontSize: 12)),
                              if ((expense["note"] ?? "").isNotEmpty)
                                Text(expense["note"], style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                  onPressed: () => _editExpense(expense)),
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _deleteExpense(expense["id"])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(context),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
