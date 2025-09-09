import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';
import 'settings_notifier.dart';
import '../services/export_service.dart';

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
    "salary": Colors.green.shade700,
    "bonus": Colors.blue.shade700,
    "investment": Colors.orange.shade800,
    "other": Colors.grey.shade600,
  };

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  String _currencySymbol = "Rp";
  String _currencyCode = "IDR";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadIncome();
    _selectedDate = DateTime.now();
  }

  void _loadSettings() {
    SettingsNotifier.instance.currentCurrency.addListener(() {
      final value = SettingsNotifier.instance.currentCurrency.value;
      final parts = value.split(" ");
      setState(() {
        _currencyCode = parts[0];
        _currencySymbol = parts.length > 1
            ? parts[1].replaceAll("(", "").replaceAll(")", "")
            : _currencyCode;
      });
    });
  }

  Future<void> _loadIncome() async {
    final data = await DatabaseHelper.instance.getIncomes();
    setState(() {
      _incomeList = data;
    });
  }

  double get _totalIncomeThisMonth {
    return _filteredIncomeList.fold(0, (sum, item) => sum + (item['amount'] as num));
  }

  List<Map<String, dynamic>> get _filteredIncomeList {
    return _incomeList.where((income) {
      final date = DateTime.parse(income["date"]);
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

  Future<void> _saveIncome() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null || _selectedDate == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr("complete_category_date"))));
        return;
      }

      final amount = _parseCurrency(_amountController.text);
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
      _selectedDate = DateTime.now();

      _loadIncome();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              tr("income_saved", args: [_formatCurrency(amount), tr(_selectedCategory ?? "other")]))));
    }
  }

  Future<void> _deleteIncome(int id) async {
    await DatabaseHelper.instance.deleteIncome(id);
    _loadIncome();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("data_deleted"))));
  }

  Future<void> _editIncome(Map<String, dynamic> income) async {
    final editAmountController =
        TextEditingController(text: _formatCurrency((income["amount"] as num).toDouble()));
    final editNoteController = TextEditingController(text: income["note"] ?? "");
    String? editCategory = income["category"];
    DateTime editDate = DateTime.parse(income["date"]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(child: Text(tr("cancel")), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(tr("save"), style: const TextStyle(color: Colors.white)),
            onPressed: () async {
              final updatedAmount = _parseCurrency(editAmountController.text);
              await DatabaseHelper.instance.updateIncome(income["id"], {
                "amount": updatedAmount,
                "category": editCategory ?? "other",
                "note": editNoteController.text,
                "date": editDate.toIso8601String(),
              });
              Navigator.pop(context);
              _loadIncome();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(tr("data_updated"))));
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
      validator: (value) => value == null || value.isEmpty ? "${tr("enter")} $label" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.green) : null,
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
        prefixIcon: icon != null ? Icon(icon, color: Colors.green) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showAddIncomeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFancyTextField(
                  controller: _amountController,
                  label: tr("amount"),
                  icon: Icons.attach_money,
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
                    child: Text(
                        DateFormat("dd/MM/yyyy", context.locale.toString()).format(_selectedDate!)),
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
                      _saveIncome();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: Text(tr("save"), style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
      ),
    );
  }

  Future<void> _sharePDF() async {
    final path = await ExportService.exportIncomePDF(
        month: _selectedMonth, year: _selectedYear);
    await ExportService.shareFile(path, text: tr("share_income_pdf"));
  }

  Future<void> _shareExcel() async {
    final path = await ExportService.exportIncomeExcel(
        month: _selectedMonth, year: _selectedYear);
    await ExportService.shareFile(path, text: tr("share_income_excel"));
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
        backgroundColor: Colors.green,
        title: Text(tr("income"), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'pdf') await _sharePDF();
              if (value == 'excel') await _shareExcel();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'pdf', child: Text(tr("share_pdf"))),
              PopupMenuItem(value: 'excel', child: Text(tr("share_excel"))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Total income bulan ini
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.green.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 28, color: Colors.green),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr("total_income_this_month"),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(_formatCurrency(_totalIncomeThisMonth),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Dropdown bulan & tahun
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
                          value: month,
                          child: Text(DateFormat.MMMM().format(DateTime(0, month))));
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
            child: _filteredIncomeList.isEmpty
                ? Center(child: Text(tr("no_data")))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredIncomeList.length,
                    itemBuilder: (context, index) {
                      final income = _filteredIncomeList[index];
                      final color = _categoryColors[income["category"]] ?? Colors.grey;
                      final date = DateTime.parse(income["date"]);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(Icons.attach_money, color: color, size: 20),
                          ),
                          title: Text(
                            _formatCurrency((income["amount"] as num).toDouble()),
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.grey.shade900, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(income["category"]),
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                              Text(DateFormat("dd/MM/yyyy", context.locale.toString()).format(date),
                                  style: const TextStyle(fontSize: 12)),
                              if ((income["note"] ?? "").isNotEmpty)
                                Text(income["note"], style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                  onPressed: () => _editIncome(income)),
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _deleteIncome(income["id"])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "add_income",
            onPressed: () => _showAddIncomeSheet(context),
            backgroundColor: Colors.green,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "share_income",
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                              leading: const Icon(Icons.picture_as_pdf),
                              title: Text(tr("share_pdf")),
                              onTap: () {
                                Navigator.pop(context);
                                _sharePDF();
                              }),
                          ListTile(
                              leading: const Icon(Icons.grid_on),
                              title: Text(tr("share_excel")),
                              onTap: () {
                                Navigator.pop(context);
                                _shareExcel();
                              }),
                        ],
                      ));
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
