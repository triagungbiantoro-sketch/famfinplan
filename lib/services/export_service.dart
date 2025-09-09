// lib/services/export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import '../db/database_helper.dart';

class ExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  /// ---------------- PDF ----------------
  static Future<String> exportIncomePDF({int? month, int? year}) async {
    final allIncome = await DatabaseHelper.instance.getIncomes();
    final income = allIncome.where((i) {
      final date = DateTime.parse(i['date']);
      if (month != null && date.month != month) return false;
      if (year != null && date.year != year) return false;
      return true;
    }).toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Income', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['ID', 'Tanggal', 'Kategori', 'Jumlah', 'Catatan'],
              data: income.map((i) => [
                i['id'].toString(),
                _dateFormat.format(DateTime.parse(i['date'])),
                i['category'] ?? '',
                NumberFormat('#,##0').format(i['amount']),
                i['note'] ?? '',
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    final dir = await _getDownloadDirectory();
    final filePath = '${dir.path}/Income_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  static Future<String> exportExpensePDF({int? month, int? year}) async {
    final allExpense = await DatabaseHelper.instance.getExpenses();
    final expense = allExpense.where((e) {
      final date = DateTime.parse(e['date']);
      if (month != null && date.month != month) return false;
      if (year != null && date.year != year) return false;
      return true;
    }).toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Expense', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['ID', 'Tanggal', 'Kategori', 'Jumlah', 'Catatan'],
              data: expense.map((e) => [
                e['id'].toString(),
                _dateFormat.format(DateTime.parse(e['date'])),
                e['category'] ?? '',
                NumberFormat('#,##0').format(e['amount']),
                e['note'] ?? '',
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    final dir = await _getDownloadDirectory();
    final filePath = '${dir.path}/Expense_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  /// ---------------- EXCEL ----------------
  static Future<String> exportIncomeExcel({int? month, int? year}) async {
    final allIncome = await DatabaseHelper.instance.getIncomes();
    final income = allIncome.where((i) {
      final date = DateTime.parse(i['date']);
      if (month != null && date.month != month) return false;
      if (year != null && date.year != year) return false;
      return true;
    }).toList();

    var excel = Excel.createExcel();
    Sheet sheetIncome = excel['Income'];
    sheetIncome.appendRow(['ID', 'Tanggal', 'Kategori', 'Jumlah', 'Catatan']);
    for (var i in income) {
      sheetIncome.appendRow([
        i['id'].toString(),
        _dateFormat.format(DateTime.parse(i['date'])),
        i['category'] ?? '',
        i['amount'],
        i['note'] ?? '',
      ]);
    }

    final dir = await _getDownloadDirectory();
    final filePath = '${dir.path}/Income_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    final excelBytes = excel.encode();
    if (excelBytes != null) await file.writeAsBytes(excelBytes);
    return filePath;
  }

  static Future<String> exportExpenseExcel({int? month, int? year}) async {
    final allExpense = await DatabaseHelper.instance.getExpenses();
    final expense = allExpense.where((e) {
      final date = DateTime.parse(e['date']);
      if (month != null && date.month != month) return false;
      if (year != null && date.year != year) return false;
      return true;
    }).toList();

    var excel = Excel.createExcel();
    Sheet sheetExpense = excel['Expense'];
    sheetExpense.appendRow(['ID', 'Tanggal', 'Kategori', 'Jumlah', 'Catatan']);
    for (var e in expense) {
      sheetExpense.appendRow([
        e['id'].toString(),
        _dateFormat.format(DateTime.parse(e['date'])),
        e['category'] ?? '',
        e['amount'],
        e['note'] ?? '',
      ]);
    }

    final dir = await _getDownloadDirectory();
    final filePath = '${dir.path}/Expense_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    final excelBytes = excel.encode();
    if (excelBytes != null) await file.writeAsBytes(excelBytes);
    return filePath;
  }

  /// ---------------- SHARE ----------------
  static Future<void> shareFile(String path, {String? text}) async {
    await Share.shareXFiles([XFile(path)], text: text ?? 'FamFinPlan Data');
  }

  /// ---------------- HELPERS ----------------
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final downloadDir = Directory('${dir.path}/Download');
        if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
        return downloadDir;
      } else {
        final fallback = Directory('/storage/emulated/0/Download');
        if (!await fallback.exists()) await fallback.create(recursive: true);
        return fallback;
      }
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }
}
