// lib/screens/vehicle_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../db/kendaraan_db.dart';
import '../services/notification_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  final List<String> _vehicleTypes = ['vehicle_type_motorcycle', 'vehicle_type_car'];

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    NotificationService.instance.init();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // test ad unit ID
          : 'ca-app-pub-3940256099942544/4411468910', // iOS test ad unit
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (err) {
          debugPrint('InterstitialAd failed to load: $err');
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // load next ad
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  Future<void> _loadVehicles() async {
    final data = await KendaraanDB.instance.getVehicles();
    setState(() => _vehicles = data);
  }

  Future<void> _scheduleOilReminder(DateTime oilDate, String plate) async {
    if (oilDate.isBefore(DateTime.now())) return;
    try {
      await NotificationService.instance.scheduleNotification(
        oilDate.millisecondsSinceEpoch % 100000,
        "oil_reminder_title".tr(),
        "oil_reminder_body".tr(namedArgs: {
          "plate": plate,
          "date": DateFormat('dd/MM/yyyy').format(oilDate),
        }),
        oilDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notification_error'.tr() + ': $e')),
        );
      }
    }
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("delete_confirm_title".tr(),
            style: const TextStyle(color: Colors.cyanAccent)),
        content: Text("delete_confirm_message".tr(),
            style: const TextStyle(color: Colors.white70)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr(),
                style: const TextStyle(color: Colors.cyanAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await KendaraanDB.instance.deleteVehicle(id);
              Navigator.pop(context);
              await _loadVehicles();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('vehicle_deleted'.tr())),
                );
              }
            },
            child: Text("delete".tr()),
          ),
        ],
      ),
    );
  }

  // ------------------ Form ------------------
  Future<void> _showVehicleForm({Map<String, dynamic>? vehicle}) async {
    final _formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: vehicle?['vehicleType'] ?? '');
    final plateCtrl = TextEditingController(text: vehicle?['plateNumber'] ?? '');
    final taxCtrl = TextEditingController(
        text: vehicle?['taxDate'] != null
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(vehicle!['taxDate']))
            : '');
    final oilKmCtrl = TextEditingController(text: vehicle?['lastOilKm']?.toString() ?? '');
    final monthsCtrl =
        TextEditingController(text: vehicle?['oilUsageMonths']?.toString() ?? '');
    final oilDateCtrl = TextEditingController(
        text: vehicle?['lastOilDate'] != null
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(vehicle!['lastOilDate']))
            : '');

    Future<void> saveData() async {
      if (!_formKey.currentState!.validate()) return;

      DateTime? taxDate = taxCtrl.text.isNotEmpty
          ? DateFormat('dd/MM/yyyy').parse(taxCtrl.text)
          : null;
      DateTime? lastOilDate = oilDateCtrl.text.isNotEmpty
          ? DateFormat('dd/MM/yyyy').parse(oilDateCtrl.text)
          : null;
      int? oilUsageMonths = int.tryParse(monthsCtrl.text);
      DateTime? nextOilDate;
      if (lastOilDate != null && oilUsageMonths != null) {
        nextOilDate = DateTime(
            lastOilDate.year, lastOilDate.month + oilUsageMonths, lastOilDate.day);
      }

      final newVehicle = {
        "vehicleType": typeCtrl.text,
        "plateNumber": plateCtrl.text,
        "taxDate": taxDate?.toIso8601String(),
        "lastOilKm": int.tryParse(oilKmCtrl.text),
        "oilUsageMonths": oilUsageMonths,
        "lastOilDate": lastOilDate?.toIso8601String(),
        "nextOilDate": nextOilDate?.toIso8601String(),
      };

      if (vehicle == null) {
        await KendaraanDB.instance.insertVehicle(newVehicle);
      } else {
        await KendaraanDB.instance.updateVehicle(vehicle['id'], newVehicle);
      }

      if (nextOilDate != null) {
        await _scheduleOilReminder(nextOilDate, plateCtrl.text);
      }

      Navigator.pop(context);
      await _loadVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(vehicle == null
                  ? 'vehicle_saved'.tr()
                  : 'vehicle_updated'.tr())),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(vehicle == null ? "add_vehicle".tr() : "edit_vehicle".tr(),
            style: const TextStyle(color: Colors.cyanAccent)),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Type Dropdown
                DropdownButtonFormField<String>(
                  value: _vehicleTypes.contains(typeCtrl.text) ? typeCtrl.text : null,
                  items: _vehicleTypes
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.tr(), style: const TextStyle(color: Colors.white)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => typeCtrl.text = val ?? '',
                  dropdownColor: Colors.grey[900],
                  validator: (v) => v == null || v.isEmpty ? "select_vehicle_type".tr() : null,
                  decoration: const InputDecoration(
                    labelText: "Type",
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(plateCtrl, "plate_number".tr()),
                const SizedBox(height: 8),
                _buildDateField(taxCtrl, "tax_date".tr()),
                const SizedBox(height: 8),
                _buildTextField(oilKmCtrl, "last_oil_km".tr(), keyboard: TextInputType.number),
                const SizedBox(height: 8),
                _buildTextField(monthsCtrl, "oil_usage_months".tr(),
                    keyboard: TextInputType.number),
                const SizedBox(height: 8),
                _buildDateField(oilDateCtrl, "last_oil_date".tr()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("cancel", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text("save"),
            onPressed: saveData,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label,
      {TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.cyanAccent),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null || v.isEmpty ? "required".tr() : null,
    );
  }

  Widget _buildDateField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.cyanAccent),
        suffixIcon: const Icon(Icons.calendar_today, color: Colors.cyanAccent),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDate: DateTime.now(),
          builder: (ctx, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.cyanAccent,
                  onPrimary: Colors.black,
                  surface: Colors.grey,
                  onSurface: Colors.white70,
                ),
                dialogBackgroundColor: Colors.grey[900],
              ),
              child: child!,
            );
          },
        );
        if (picked != null) ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
      },
    );
  }

  Widget _buildPriorityChip(String label, String value) {
    Color bgColor;
    switch (label) {
      case "last_oil_date":
      case "next_oil_date":
        bgColor = Colors.orangeAccent;
        break;
      case "tax_date":
        bgColor = Colors.greenAccent;
        break;
      default:
        bgColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 6, top: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: bgColor.withOpacity(0.7), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Text(
        "$label: $value",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.cyanAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(v['vehicleType'] as String).tr()} - ${v['plateNumber']}',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [
                      Shadow(
                        color: Colors.cyanAccent,
                        blurRadius: 8,
                        offset: Offset(0, 0),
                      ),
                      Shadow(
                        color: Colors.cyanAccent,
                        blurRadius: 16,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Wrap(
              children: [
                _buildPriorityChip("tax_date".tr(),
                    v['taxDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate'])) : '-'),
                _buildPriorityChip("last_oil_km".tr(), v['lastOilKm']?.toString() ?? '-'),
                _buildPriorityChip("oil_usage_months".tr(), v['oilUsageMonths']?.toString() ?? '-'),
                _buildPriorityChip("last_oil_date".tr(),
                    v['lastOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate'])) : '-'),
                _buildPriorityChip("next_oil_date".tr(),
                    v['nextOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate'])) : '-'),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _showInterstitialAd(); // <-- tampilkan interstitial sebelum form
                    _showVehicleForm(vehicle: v);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: () => _shareText(v),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.share, color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: () => _exportVehicleToPdf(v),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: () => _showDeleteDialog(v['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareText(Map<String, dynamic> v) {
    final lines = <String>[];
    lines.add('${(v['vehicleType'] as String).tr()} - ${v['plateNumber']}');
    lines.add(
        '${"tax_date".tr()}: ${v['taxDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate'])) : '-'}');
    lines.add('${"last_oil_km".tr()}: ${v['lastOilKm'] ?? '-'}');
    lines.add('${"oil_usage_months".tr()}: ${v['oilUsageMonths'] ?? '-'}');
    lines.add(
        '${"last_oil_date".tr()}: ${v['lastOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate'])) : '-'}');
    lines.add(
        '${"next_oil_date".tr()}: ${v['nextOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate'])) : '-'}');

    Share.share(lines.join('\n'), subject: 'vehicle_data'.tr());
  }

  Future<void> _exportVehicleToPdf(Map<String, dynamic> v) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('vehicle_data'.tr(),
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('${(v['vehicleType'] as String).tr()} - ${v['plateNumber']}'),
                pw.Text('${"tax_date".tr()}: ${v['taxDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate'])) : '-'}'),
                pw.Text('${"last_oil_km".tr()}: ${v['lastOilKm'] ?? '-'}'),
                pw.Text('${"oil_usage_months".tr()}: ${v['oilUsageMonths'] ?? '-'}'),
                pw.Text('${"last_oil_date".tr()}: ${v['lastOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate'])) : '-'}'),
                pw.Text('${"next_oil_date".tr()}: ${v['nextOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate'])) : '-'}'),
              ],
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${v['plateNumber']}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'vehicle_data'.tr());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('pdf_export_error'.tr() + ': $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("vehicle_screen_title".tr()),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.cyanAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListView.builder(
          itemCount: _vehicles.length,
          itemBuilder: (_, i) => _buildVehicleCard(_vehicles[i]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        onPressed: () {
          _showInterstitialAd(); // tampilkan ad saat FAB ditekan
          _showVehicleForm();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
