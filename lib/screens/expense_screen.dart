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
    "food": Colors.orange,
    "transport": Colors.blue,
    "shopping": Colors.green,
    "bills": Colors.purple,
    "other": Colors.grey,
  };

  // Currency
  String _currencySymbol = "Rp";
  String _currencyCode = "IDR";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadExpenses();

    // ✅ Set default tanggal = hari ini
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

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now, // ✅ default hari ini atau tanggal terakhir dipilih
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
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
      _selectedDate = DateTime.now(); // ✅ reset kembali ke tanggal hari ini

      _loadExpenses();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              tr("expense_saved", args: [_formatCurrency(amount), tr(_selectedCategory ?? "other")])),
        ),
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
                  child: Text(DateFormat("dd/MM/yyyy", context.locale.toString())
                      .format(editDate)),
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
    return Focus(
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: isFocused ? 10 : 4,
                  offset: Offset(0, isFocused ? 6 : 3),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                validator: (value) =>
                    value == null || value.isEmpty ? "${tr("enter")} $label" : null,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          );
        },
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
      items: items
          .map((cat) => DropdownMenuItem(value: cat, child: Text(tr(cat))))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? "${tr("choose")} $label" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
        title: Text(tr("add_expense"), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildFancyTextField(
                    controller: _amountController,
                    label: tr("amount"),
                    icon: Icons.money_off,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildFancyDropdown(
                    label: tr("category"),
                    value: _selectedCategory,
                    items: _categories,
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    icon: Icons.category,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr("date"),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(DateFormat("dd/MM/yyyy", context.locale.toString())
                          .format(_selectedDate!)), // ✅ default hari ini
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFancyTextField(
                      controller: _noteController, label: tr("note"), icon: Icons.note_alt),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveExpense,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(tr("save"), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Text(tr("expense_list"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ValueListenableBuilder<String>(
              valueListenable: SettingsNotifier.instance.currentCurrency,
              builder: (context, currencyValue, child) {
                final parts = currencyValue.split(" ");
                final currencyCode = parts[0];
                final currencySymbol = parts.length > 1
                    ? parts[1].replaceAll("(", "").replaceAll(")", "")
                    : currencyCode;

                String formatCurrency(double value) {
                  final locale = currencyCode == "IDR" ? "id_ID" : "en_US";
                  final decimalDigits = currencyCode == "IDR" ? 0 : 2;
                  return NumberFormat.currency(
                          locale: locale, symbol: currencySymbol, decimalDigits: decimalDigits)
                      .format(value);
                }

                return _expenseList.isEmpty
                    ? Center(child: Text(tr("no_data")))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.resolveWith(
                              (states) => Colors.blueGrey[50]),
                          headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black87),
                          columnSpacing: 20,
                          columns: [
                            DataColumn(label: Text(tr("amount"))),
                            DataColumn(label: Text(tr("category"))),
                            DataColumn(label: Text(tr("date"))),
                            DataColumn(label: Text(tr("note"))),
                            DataColumn(label: Text(tr("action"))),
                          ],
                          rows: _expenseList.map((expense) {
                            final date = DateTime.parse(expense["date"]);
                            final color =
                                _categoryColors[expense["category"]] ?? Colors.grey;

                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  formatCurrency((expense["amount"] as num).toDouble()),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                )),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tr(expense["category"] ?? ""),
                                    style: TextStyle(
                                        color: color, fontWeight: FontWeight.bold),
                                  ),
                                )),
                                DataCell(Text(DateFormat("dd/MM/yyyy", context.locale.toString())
                                    .format(date))),
                                DataCell(Text(expense["note"] ?? "-")),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                        onPressed: () => _editExpense(expense)),
                                    IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteExpense(expense["id"])),
                                  ],
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}
