import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedDate;

  List<Map<String, dynamic>> _incomeList = [];
  final List<String> _categories = ["salary", "bonus", "investment", "other"];

  final Map<String, Color> _categoryColors = {
    "salary": Colors.green,
    "bonus": Colors.blue,
    "investment": Colors.orange,
    "other": Colors.grey,
  };

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadIncome();
  }

  Future<void> _loadIncome() async {
    final data = await DatabaseHelper.instance.getIncomes();
    setState(() {
      _incomeList = data;
    });
  }

  Future<void> _saveIncome() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null || _selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("complete_category_date"))),
        );
        return;
      }

      final amount = double.tryParse(_amountController.text) ?? 0;
      final note = _noteController.text;

      await DatabaseHelper.instance.insertIncome({
        "amount": amount,
        "category": _selectedCategory!,
        "note": note,
        "date": _selectedDate!.toIso8601String(),
      });

      _amountController.clear();
      _noteController.clear();
      _selectedCategory = null;
      _selectedDate = null;

      _loadIncome();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("data_saved"))),
      );
    }
  }

  Future<void> _deleteIncome(int id) async {
    await DatabaseHelper.instance.deleteIncome(id);
    _loadIncome();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("data_deleted"))),
    );
  }

  Future<void> _editIncome(Map<String, dynamic> income) async {
    final editAmountController =
        TextEditingController(text: income["amount"].toString());
    final editNoteController =
        TextEditingController(text: income["note"] ?? "");
    String? editCategory = income["category"];
    DateTime editDate = DateTime.parse(income["date"]);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr("edit_income")),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildFancyTextField(
                  controller: editAmountController,
                  label: tr("amount"),
                  icon: Icons.attach_money,
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
                    if (picked != null) {
                      setState(() {
                        editDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr("date"),
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      DateFormat("dd/MM/yyyy", context.locale.toString())
                          .format(editDate),
                    ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text(tr("save")),
              onPressed: () async {
                await DatabaseHelper.instance.updateIncome(income["id"], {
                  "amount": double.tryParse(editAmountController.text) ?? 0,
                  "category": editCategory ?? "other",
                  "note": editNoteController.text,
                  "date": editDate.toIso8601String(),
                });
                Navigator.pop(context);
                _loadIncome();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr("data_updated"))),
                );
              },
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredIncomeList {
    return _incomeList.where((income) {
      final date = DateTime.parse(income["date"]);
      return date.month == _selectedMonth && date.year == _selectedYear;
    }).toList();
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                validator: (value) =>
                    value == null || value.isEmpty ? "${tr("enter")} $label" : null,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon:
                      icon != null ? Icon(icon, color: Colors.blueAccent) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
          .map((cat) => DropdownMenuItem(
              value: cat, child: Text(tr(cat))))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? "${tr("choose")} $label" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent) : null,
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
        backgroundColor: const Color.fromARGB(255, 39, 204, 94),
        title: Text(tr("add_income"), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildFancyTextField(
                    controller: _amountController,
                    label: tr("amount"),
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildFancyDropdown(
                    label: tr("category"),
                    value: _selectedCategory,
                    items: _categories,
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                    icon: Icons.category,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr("date"),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _selectedDate == null
                            ? tr("pick_date")
                            : DateFormat("dd/MM/yyyy", context.locale.toString())
                                .format(_selectedDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFancyTextField(
                    controller: _noteController,
                    label: tr("note"),
                    icon: Icons.note_alt,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveIncome,
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              tr("income_list"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat.MMMM(context.locale.toString())
                                .format(DateTime(0, m))),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMonth = val);
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(5, (i) => DateTime.now().year - i)
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text("$y"),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _filteredIncomeList.isEmpty
                ? Center(child: Text(tr("no_data")))
                : Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
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
                        rows: _filteredIncomeList.map((income) {
                          final date = DateTime.parse(income["date"]);
                          final color =
                              _categoryColors[income["category"]] ?? Colors.grey;
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                  NumberFormat.currency(
                                          locale: context.locale.toString(),
                                          symbol: "Rp",
                                          decimalDigits: 0)
                                      .format(income["amount"]),
                                  style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tr(income["category"]),
                                  style: TextStyle(
                                      color: color, fontWeight: FontWeight.bold),
                                ),
                              )),
                              DataCell(
                                  Text(DateFormat("dd/MM/yyyy", context.locale.toString())
                                      .format(date))),
                              DataCell(Text(income["note"] ?? "-")),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.orange),
                                    onPressed: () => _editIncome(income),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () =>
                                        _deleteIncome(income["id"]),
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
