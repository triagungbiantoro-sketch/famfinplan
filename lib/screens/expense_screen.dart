import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../db/database_helper.dart';
import 'settings_notifier.dart';
import '../services/export_service.dart';
import 'package:share_plus/share_plus.dart';

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
  File? _selectedImage;
  int? _editingId; // <-- untuk edit

  List<Map<String, dynamic>> _expenseList = [];
  final List<String> _categories = ["food", "transport", "shopping", "bills", "other"];

  final Map<String, Color> _categoryColors = {
    "food": Colors.orange.shade700,
    "transport": Colors.blue.shade700,
    "shopping": Colors.green.shade700,
    "bills": Colors.purple.shade700,
    "other": Colors.grey.shade600,
  };

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  String _currencySymbol = "Rp";
  String _currencyCode = "IDR";

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadSettings();
    _loadExpenses();
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

  Future<void> _loadExpenses() async {
    final data = await DatabaseHelper.instance.getExpenses();
    setState(() {
      _expenseList = data;
    });
  }

  List<Map<String, dynamic>> get _filteredExpenseList {
    return _expenseList.where((expense) {
      final date = DateTime.parse(expense["date"]);
      return date.month == _selectedMonth && date.year == _selectedYear;
    }).toList();
  }

  double get _totalExpenseThisMonth {
    return _filteredExpenseList.fold(0, (sum, item) => sum + (item['amount'] as num));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr("complete_category_date"))));
        return;
      }

      final amount = _parseCurrency(_amountController.text);
      final note = _noteController.text;

      final expenseData = {
        "amount": amount,
        "category": _selectedCategory!,
        "note": note,
        "date": _selectedDate!.toIso8601String(),
        "imagePath": _selectedImage?.path,
      };

      if (_editingId != null) {
        await DatabaseHelper.instance.updateExpense(_editingId!, expenseData);
      } else {
        await DatabaseHelper.instance.insertExpense(expenseData);
      }

      _clearForm();
      _loadExpenses();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              tr("expense_saved", args: [_formatCurrency(amount), tr(_selectedCategory ?? "other")]))));
    }
  }

  void _clearForm() {
    _amountController.clear();
    _noteController.clear();
    _selectedCategory = null;
    _selectedDate = DateTime.now();
    _selectedImage = null;
    _editingId = null;
  }

  Future<void> _confirmDeleteExpense(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("confirm_delete")),
        content: Text(tr("delete_expense_confirm")),
        actions: [
          TextButton(
            child: Text(tr("cancel")),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(tr("delete"), style: const TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteExpense(id);
    }
  }

  Future<void> _deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    _loadExpenses();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("data_deleted"))));
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  void _showAddExpenseSheet(BuildContext context, {Map<String, dynamic>? editingExpense}) {
    if (editingExpense != null) {
      _amountController.text = (editingExpense['amount'] as num).toString();
      _noteController.text = editingExpense['note'] ?? '';
      _selectedCategory = editingExpense['category'];
      _selectedDate = DateTime.parse(editingExpense['date']);
      _selectedImage =
          editingExpense['imagePath'] != null ? File(editingExpense['imagePath']) : null;
      _editingId = editingExpense['id'];
    } else {
      _clearForm();
    }

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: Text(tr("camera")),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo),
                        label: Text(tr("gallery")),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
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

  Future<void> _sharePDF() async {
    final path = await ExportService.exportExpensePDF(
        month: _selectedMonth, year: _selectedYear);
    await ExportService.shareFile(path, text: tr("share_expense_pdf"));
  }

  Future<void> _shareExcel() async {
    final path = await ExportService.exportExpenseExcel(
        month: _selectedMonth, year: _selectedYear);
    await ExportService.shareFile(path, text: tr("share_expense_excel"));
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
        title: Text(tr("expenses"), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Total expense bulan ini
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.red.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 28, color: Colors.red),
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
            child: _filteredExpenseList.isEmpty
                ? Center(child: Text(tr("no_data")))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredExpenseList.length,
                    itemBuilder: (context, index) {
                      final exp = _filteredExpenseList[index];
                      final color = _categoryColors[exp["category"]] ?? Colors.grey;
                      final date = DateTime.parse(exp["date"]);
                      final imagePath = exp["imagePath"] as String?;

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
                            _formatCurrency((exp["amount"] as num).toDouble()),
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.grey.shade900, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(exp["category"]),
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                              Text(DateFormat("dd/MM/yyyy", context.locale.toString()).format(date),
                                  style: const TextStyle(fontSize: 12)),
                              if ((exp["note"] ?? "").isNotEmpty)
                                Text(exp["note"], style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              if (imagePath != null && imagePath.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FullScreenImagePage(imageFile: File(imagePath)),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(imagePath),
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                  onPressed: () => _showAddExpenseSheet(context, editingExpense: exp)),
                              IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _confirmDeleteExpense(exp["id"]),
                                ),
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
            heroTag: "add_expense",
            onPressed: () => _showAddExpenseSheet(context),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "share_expense",
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
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.grid_on),
                            title: Text(tr("share_excel")),
                            onTap: () {
                              Navigator.pop(context);
                              _shareExcel();
                            },
                          ),
                        ],
                      ));
            },
            backgroundColor: Colors.blueGrey,
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final File imageFile;
  const FullScreenImagePage({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: Image.file(imageFile, fit: BoxFit.contain, width: double.infinity)),
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
