import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:famfinplan/db/database_helper.dart';
import 'package:famfinplan/screens/settings_notifier.dart';
import 'package:share_plus/share_plus.dart';

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
  DateTime? _selectedDateTime;

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
      _currencySymbol =
          value.split(" ")[1].replaceAll("(", "").replaceAll(")", "");
    });
  }

  String _formatCurrency(double value) {
    final locale = _currencyCode == "IDR" ? "id_ID" : "en_US";
    return NumberFormat.currency(
            locale: locale, symbol: _currencySymbol, decimalDigits: 0)
        .format(value);
  }

  Future<void> _loadBudget() async {
    final budgetData =
        await DatabaseHelper.instance.getBudget(month: _selectedMonth);
    setState(() {
      _totalBudget = (budgetData?['totalBudget'] ?? 0).toDouble();
      _usedBudget = (budgetData?['usedBudget'] ?? 0).toDouble();
    });
    final usageData =
        await DatabaseHelper.instance.getBudgetUsage(month: _selectedMonth);
    setState(() {
      _usageList
        ..clear()
        ..addAll(usageData);
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year,
          _selectedMonth.month + offset, 1);
    });
    _loadBudget();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _addUsage(
      {double? amount, String? note, DateTime? notifyAt}) async {
    final amt = amount ??
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final nt = note ?? _noteController.text;
    final notify = notifyAt ?? _selectedDateTime;

    if (_usedBudget + amt <= _totalBudget) {
      await DatabaseHelper.instance.addBudgetUsage(
        amt,
        nt,
        month: _selectedMonth,
        notifyAt: notify,
      );
      _amountController.clear();
      _noteController.clear();
      _selectedDateTime = null;
      await _loadBudget();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr("usage_added", args: [_formatCurrency(amt), nt]))),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr("budget_exceeded"))));
    }
  }

  void _showAddUsageSheet({Map<String, dynamic>? usage}) {
    final isEdit = usage != null;
    if (isEdit) {
      _amountController.text = usage['amount'].toString();
      _noteController.text = usage['note'] ?? "";
      _selectedDateTime = usage['notify_at'] != null
          ? DateTime.tryParse(usage['notify_at'])
          : null;
    } else {
      _amountController.clear();
      _noteController.clear();
      _selectedDateTime = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? tr("edit_usage") : tr("add_usage"),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: tr("usage_amount"),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.money_off),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: tr("note_example"),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.note_alt),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.alarm),
                label: Text(
                  _selectedDateTime == null
                      ? tr("add_notification_time")
                      : DateFormat("dd MMM yyyy, HH:mm")
                          .format(_selectedDateTime!),
                ),
                onPressed: _pickDateTime,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (isEdit) {
                      final newAmount = double.tryParse(
                              _amountController.text.replaceAll(',', '')) ??
                          0;
                      final newNote = _noteController.text;
                      final diff =
                          newAmount - (usage!['amount'] as num).toDouble();
                      if (_usedBudget + diff <= _totalBudget) {
                        await DatabaseHelper.instance.updateBudgetUsage(
                          usage['id'],
                          newAmount,
                          newNote,
                          month: _selectedMonth,
                          notifyAt: _selectedDateTime,
                        );
                        await _loadBudget();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(tr("usage_updated", args: [
                            _formatCurrency(newAmount),
                            newNote
                          ]))),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr("budget_exceeded"))),
                        );
                      }
                    } else {
                      await _addUsage();
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(isEdit ? Icons.save : Icons.add, color: Colors.white),
                  label: Text(isEdit ? tr("save") : tr("add_usage"),
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBudgetSheet() {
    final editController = TextEditingController(text: _totalBudget.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr("edit_monthly_budget"),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: editController,
              decoration: InputDecoration(
                labelText: tr("monthly_total_budget"),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.account_balance_wallet),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label:
                    Text(tr("save"), style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newTotal = double.tryParse(
                          editController.text.replaceAll(',', '')) ??
                      _totalBudget;
                  if (newTotal >= _usedBudget) {
                    await DatabaseHelper.instance.updateBudgetTotal(newTotal,
                        month: _selectedMonth);
                    await _loadBudget();
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr("total_less_than_used"))),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === ADD BUDGET SHEET ===
  void _showAddBudgetSheet() {
    final addController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr("add_monthly_budget"),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: addController,
              decoration: InputDecoration(
                labelText: tr("monthly_total_budget"),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.account_balance_wallet),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(tr("add_budget"),
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newTotal =
                      double.tryParse(addController.text.replaceAll(',', '')) ??
                          0;
                  if (newTotal > 0) {
                    await DatabaseHelper.instance.addBudget(newTotal,
                        month: _selectedMonth);
                    await _loadBudget();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              tr("budget_added", args: [_formatCurrency(newTotal)]))),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr("invalid_budget"))),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return Colors.green;
    if (progress < 0.8) return Colors.orange;
    return Colors.red;
  }

  Future<void> _shareBudgetSummary() async {
    final buffer = StringBuffer();
    buffer.writeln(
        "${tr("monthly_budget_summary")}: ${DateFormat.yMMM().format(_selectedMonth)}");
    buffer.writeln("${tr("total_budget")}: ${_formatCurrency(_totalBudget)}");
    buffer.writeln("${tr("used")}: ${_formatCurrency(_usedBudget)}");
    buffer.writeln(
        "${tr("remaining")}: ${_formatCurrency(_totalBudget - _usedBudget)}");
    buffer.writeln("\n${tr("usage_list")}:");
    for (var usage in _usageList) {
      final dateText = usage['notify_at'] != null
          ? DateFormat("dd/MM/yyyy HH:mm")
              .format(DateTime.parse(usage['notify_at']))
          : "-";
      buffer.writeln(
          "${_formatCurrency((usage['amount'] as num).toDouble())} - ${usage['note'] ?? ""} ($dateText)");
    }

    await Share.share(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final double remaining = _totalBudget - _usedBudget;
    final double progress =
        _totalBudget > 0 ? (_usedBudget / _totalBudget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title:
            Text(tr("budget_planning"), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_left),
                    onPressed: () => _changeMonth(-1)),
                Text(DateFormat.yMMM().format(_selectedMonth),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.arrow_right),
                    onPressed: () => _changeMonth(1)),
              ],
            ),
          ),

          // Budget Summary Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.red.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tr("monthly_budget_summary"),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: _showEditBudgetSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      color: _getProgressColor(progress),
                      minHeight: 12),
                  const SizedBox(height: 8),
                  Text(
                    "${tr("used")}: ${_formatCurrency(_usedBudget)} | ${tr("remaining")}: ${_formatCurrency(remaining)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _usageList.isEmpty
                ? Center(child: Text(tr("no_data")))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _usageList.length,
                    itemBuilder: (context, index) {
                      final usage = _usageList[index];
                      final dateText = usage['notify_at'] != null
                          ? DateFormat("dd/MM/yyyy HH:mm")
                              .format(DateTime.parse(usage['notify_at']))
                          : "-";
                      final realized = (usage['realized'] ?? 0) == 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    Colors.redAccent.withOpacity(0.2),
                                child: const Icon(Icons.money_off,
                                    color: Colors.redAccent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatCurrency(
                                          (usage['amount'] as num).toDouble()),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if ((usage['note'] ?? "").isNotEmpty)
                                      Text(
                                        usage['note'] ?? "",
                                        style:
                                            const TextStyle(color: Colors.black54),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    Text(
                                      dateText,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black45),
                                    ),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: realized,
                                          onChanged: (_) async {
                                            await DatabaseHelper.instance
                                                .updateBudgetUsageRealized(
                                              usage['id'],
                                              !realized,
                                              month: _selectedMonth,
                                            );
                                            await _loadBudget();
                                          },
                                        ),
                                        Flexible(
                                          child: Text(
                                            realized ? tr("realized") : tr("pending"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.orange),
                                    onPressed: () =>
                                        _showAddUsageSheet(usage: usage),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await DatabaseHelper.instance
                                          .deleteBudgetUsage(usage['id'],
                                              month: _selectedMonth);
                                      await _loadBudget();
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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
            heroTag: "addUsage",
            onPressed: () => _showAddUsageSheet(),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "addBudget",
            onPressed: _showAddBudgetSheet,
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.account_balance_wallet, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "shareBudget",
            onPressed: _shareBudgetSummary,
            backgroundColor: Colors.green,
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
