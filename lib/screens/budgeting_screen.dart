import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:famfinplan/db/database_helper.dart';
import 'package:famfinplan/screens/settings_notifier.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

  bool _isFabOpen = false;

  // --- AdMob Banner ---
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _initSettingsAndLoadBudget();
    DatabaseHelper.instance.dataChanged.addListener(_loadBudget);

    // Initialize AdMob Banner
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/9214589741', // ganti dengan ID AdMob-mu
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd.load();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    DatabaseHelper.instance.dataChanged.removeListener(_loadBudget);
    _bannerAd.dispose();
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
                          newAmount - (usage['amount'] as num).toDouble();
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

  void _toggleFabMenu() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
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
      final realized = (usage['realized'] ?? 0) == 1;
      buffer.writeln(
          "${_formatCurrency((usage['amount'] as num).toDouble())} - ${usage['note'] ?? ""} ($dateText) [${realized ? "✓" : "✗"}]");
    }

    await Share.share(buffer.toString());
  }

  Future<void> _shareBudgetAsPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "${tr("monthly_budget_summary")}: ${DateFormat.yMMM().format(_selectedMonth)}",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text("${tr("total_budget")}: ${_formatCurrency(_totalBudget)}"),
            pw.Text("${tr("used")}: ${_formatCurrency(_usedBudget)}"),
            pw.Text(
                "${tr("remaining")}: ${_formatCurrency(_totalBudget - _usedBudget)}"),
            pw.SizedBox(height: 10),
            pw.Text("${tr("usage_list")}:"),
            pw.SizedBox(height: 4),
            for (var usage in _usageList)
              pw.Text(
                "${_formatCurrency((usage['amount'] as num).toDouble())} - ${usage['note'] ?? ""} (${usage['notify_at'] != null ? DateFormat("dd/MM/yyyy HH:mm").format(DateTime.parse(usage['notify_at'])) : "-"}) [${(usage['realized'] ?? 0) == 1 ? "✓" : "✗"}]",
              ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/budget_summary.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: "Budget Summary PDF");
  }

  Future<void> _toggleRealized(Map<String, dynamic> usage) async {
    final current = (usage['realized'] ?? 0) == 1;
    final newValue = current ? 0 : 1;
    await DatabaseHelper.instance.updateUsageRealized(usage['id'], newValue);
    await _loadBudget();
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
          // --- Banner Ad ---
          if (_isBannerAdReady)
            SizedBox(
              width: _bannerAd.size.width.toDouble(),
              height: _bannerAd.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd),
            ),

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

          // Chart
          SizedBox(
            height: 200,
            child: _usageList.isEmpty
                ? const Center(child: Text("No Data"))
                : BarChart(
                    BarChartData(
                      barGroups: _usageList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final usage = entry.value;
                        final amt = (usage['amount'] as num).toDouble();
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                              BarChartRodData(
                                toY: amt,
                                color: (usage['realized'] ?? 0) == 1 ? Colors.green : Colors.redAccent,
                                width: 16,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: true),
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
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateText,
                                      style: const TextStyle(
                                          color: Colors.black38, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleRealized(usage),
                                          child: Icon(
                                            realized
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: realized
                                                ? Colors.green
                                                : Colors.grey,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          realized
                                              ? tr("realized")
                                              : tr("not_realized"),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: realized
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!realized)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _showAddUsageSheet(usage: usage),
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

      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSlide(
            offset: _isFabOpen ? Offset(0, 0) : Offset(-0.5, 0),
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isFabOpen ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FloatingActionButton(
                  heroTag: "shareBudget",
                  mini: true,
                  backgroundColor: Colors.green,
                  onPressed: () {
                        _toggleFabMenu();
                        _shareBudgetAsPdf();
                      },
                  child: const Icon(Icons.share, color: Colors.white),
                ),
              ),
            ),
          ),
          AnimatedSlide(
            offset: _isFabOpen ? Offset(0, 0) : Offset(-0.5, 0),
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isFabOpen ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FloatingActionButton(
                  heroTag: "addUsageMini",
                  mini: true,
                  backgroundColor: Colors.redAccent,
                  onPressed: () {
                    _toggleFabMenu();
                    _showAddUsageSheet();
                  },
                  child: const Icon(Icons.money_off, color: Colors.white),
                ),
              ),
            ),
          ),
          AnimatedSlide(
            offset: _isFabOpen ? Offset(0, 0) : Offset(-0.5, 0),
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isFabOpen ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FloatingActionButton(
                  heroTag: "addBudgetMini",
                  mini: true,
                  backgroundColor: Colors.orange,
                  onPressed: () {
                    _toggleFabMenu();
                    _showAddBudgetDialog();
                  },
                  child: const Icon(Icons.attach_money, color: Colors.white),
                ),
              ),
            ),
          ),
          FloatingActionButton(
            heroTag: "mainFab",
            onPressed: _toggleFabMenu,
            backgroundColor: Colors.redAccent,
            child:
                Icon(_isFabOpen ? Icons.close : Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetDialog() {
    _budgetController.text = _totalBudget.toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("set_budget")),
        content: TextField(
          controller: _budgetController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.money),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr("cancel"))),
          ElevatedButton(
              onPressed: () async {
                final val =
                    double.tryParse(_budgetController.text.replaceAll(',', ''));
                if (val != null) {
                  await DatabaseHelper.instance.setBudget(val, month: _selectedMonth);
                  await _loadBudget();
                  Navigator.pop(context);
                }
              },
              child: Text(tr("save"))),
        ],
      ),
    );
  }
}
