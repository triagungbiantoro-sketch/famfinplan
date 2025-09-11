// lib/screens/vehicle_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../db/kendaraan_db.dart';
import '../services/notification_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  final List<String> _vehicleTypes = [
    'vehicle_type_motorcycle',
    'vehicle_type_car',
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    NotificationService.instance.init();
  }

  Future<void> _loadVehicles() async {
    final data = await KendaraanDB.instance.getVehicles();
    setState(() => _vehicles = data);
  }

  // schedule reminder using NotificationService API: scheduleNotification(id, title, body, scheduledDate)
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
      // ignore scheduling errors but inform user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notification_error'.tr() + ': $e')),
        );
      }
    }
  }

  // delete confirm dialog
  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("delete_confirm_title".tr(),
            style: const TextStyle(color: Colors.white)),
        content: Text("delete_confirm_message".tr(),
            style: const TextStyle(color: Colors.white70)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr(),
                style: const TextStyle(color: Colors.blueAccent)),
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

  // ------------------ FORM (Bottom Sheet) ------------------
  void _showVehicleForm({Map<String, dynamic>? vehicle}) {
    final _formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: vehicle?['vehicleType'] ?? '');
    final plateCtrl = TextEditingController(text: vehicle?['plateNumber'] ?? '');
    final taxCtrl = TextEditingController(
      text: vehicle?['taxDate'] != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(vehicle!['taxDate']))
          : '',
    );
    final oilKmCtrl = TextEditingController(text: vehicle?['lastOilKm']?.toString() ?? '');
    final monthsCtrl =
        TextEditingController(text: vehicle?['oilUsageMonths']?.toString() ?? '');
    final oilDateCtrl = TextEditingController(
      text: vehicle?['lastOilDate'] != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(vehicle!['lastOilDate']))
          : '',
    );

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
        nextOilDate = DateTime(lastOilDate.year,
            lastOilDate.month + oilUsageMonths, lastOilDate.day);
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
          SnackBar(content: Text(vehicle == null ? 'vehicle_saved'.tr() : 'vehicle_updated'.tr())),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.black.withOpacity(0.75),
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vehicle == null ? "add_vehicle".tr() : "edit_vehicle".tr(),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    // vehicle type
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
                      dropdownColor: Colors.black87,
                      validator: (v) => v == null || v.isEmpty ? "select_vehicle_type".tr() : null,
                      decoration: _fieldDeco("vehicle_type".tr(), Icons.directions_car),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),

                    // plate
                    _buildTextField(plateCtrl, "plate_number".tr(), Icons.confirmation_number,
                        validator: (v) => v == null || v.isEmpty ? "required".tr() : null),
                    const SizedBox(height: 10),

                    // tax date
                    _buildDateField(taxCtrl, "tax_date".tr(), Icons.event),
                    const SizedBox(height: 10),

                    // last oil km
                    _buildTextField(oilKmCtrl, "last_oil_km".tr(), Icons.speed,
                        keyboard: TextInputType.number),
                    const SizedBox(height: 10),

                    // oil usage months
                    _buildTextField(monthsCtrl, "oil_usage_months".tr(), Icons.calendar_month,
                        keyboard: TextInputType.number),
                    const SizedBox(height: 10),

                    // last oil date
                    _buildDateField(oilDateCtrl, "last_oil_date".tr(), Icons.build),
                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text("save".tr(), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A5AE0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: saveData,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------ SHARE & PDF ------------------

  // share text (quick)
  void _shareText(Map<String, dynamic> v) {
    final lines = <String>[];
    lines.add('${(v['vehicleType'] as String).tr()} - ${v['plateNumber']}');
    lines.add('${"tax_date".tr()}: ${v['taxDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate'])) : '-'}');
    lines.add('${"last_oil_km".tr()}: ${v['lastOilKm'] ?? '-'}');
    lines.add('${"oil_usage_months".tr()}: ${v['oilUsageMonths'] ?? '-'}');
    lines.add('${"last_oil_date".tr()}: ${v['lastOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate'])) : '-'}');
    lines.add('${"next_oil_date".tr()}: ${v['nextOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate'])) : '-'}');

    final shareText = lines.join('\n');
    Share.share(shareText, subject: 'vehicle_data'.tr());
  }

  // export single vehicle to PDF and share
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
                  pw.Header(level: 0, child: pw.Text('vehicle_data'.tr(), style: pw.TextStyle(fontSize: 22))),
                  pw.SizedBox(height: 6),
                  pw.Text('${"vehicle_type".tr()}: ${(v['vehicleType'] as String).tr()}'),
                  pw.Text('${"plate_number".tr()}: ${v['plateNumber']}'),
                  pw.Text('${"tax_date".tr()}: ${v['taxDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate'])) : '-'}'),
                  pw.Text('${"last_oil_km".tr()}: ${v['lastOilKm'] ?? '-'}'),
                  pw.Text('${"oil_usage_months".tr()}: ${v['oilUsageMonths'] ?? '-'}'),
                  pw.Text('${"last_oil_date".tr()}: ${v['lastOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate'])) : '-'}'),
                  pw.Text('${"next_oil_date".tr()}: ${v['nextOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate'])) : '-'}'),
                ]);
          },
        ),
      );

      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/vehicle_${v['plateNumber']}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], subject: 'vehicle_data'.tr());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('pdf_error'.tr() + ': $e')));
      }
    }
  }

  // export ALL vehicles to single PDF
  Future<void> _exportAllToPdf() async {
    if (_vehicles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('no_data'.tr())));
      }
      return;
    }

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (ctx) {
            return [
              pw.Header(level: 0, child: pw.Text('vehicle_data'.tr(), style: pw.TextStyle(fontSize: 22))),
              pw.SizedBox(height: 8),
              ..._vehicles.map((v) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('${(v['vehicleType'] as String).tr()} - ${v['plateNumber']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${"tax_date".tr()}: ${v['taxDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate'])) : '-'}'),
                    pw.Text('${"last_oil_km".tr()}: ${v['lastOilKm'] ?? '-'}'),
                    pw.Text('${"oil_usage_months".tr()}: ${v['oilUsageMonths'] ?? '-'}'),
                    pw.Text('${"last_oil_date".tr()}: ${v['lastOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate'])) : '-'}'),
                    pw.Text('${"next_oil_date".tr()}: ${v['nextOilDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate'])) : '-'}'),
                    pw.Divider(),
                  ]),
                );
              })
            ];
          },
        ),
      );

      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/vehicles_all.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], subject: 'vehicle_data'.tr());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('pdf_error'.tr() + ': $e')));
      }
    }
  }

  // ------------------ UI helpers ------------------

  InputDecoration _fieldDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDeco(label, icon),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDeco(label, icon).copyWith(suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70)),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDate: DateTime.now(),
        );
        if (picked != null) controller.text = DateFormat('dd/MM/yyyy').format(picked);
      },
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text("$label: $value", style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  '${(v['vehicleType'] as String).tr()} - ${v['plateNumber']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'share'.tr(),
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareText(v),
                ),
                IconButton(
                  tooltip: 'pdf'.tr(),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  onPressed: () => _exportVehicleToPdf(v),
                ),
                IconButton(
                  tooltip: 'edit'.tr(),
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _showVehicleForm(vehicle: v),
                ),
                IconButton(
                  tooltip: 'delete'.tr(),
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _showDeleteDialog(v['id']),
                ),
              ])
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 8, children: [
              if (v['taxDate'] != null) _infoChip('tax_date'.tr(), DateFormat('dd/MM/yyyy').format(DateTime.parse(v['taxDate']))),
              if (v['lastOilKm'] != null) _infoChip('last_oil_km'.tr(), '${v['lastOilKm']} km'),
              if (v['oilUsageMonths'] != null) _infoChip('oil_usage_months'.tr(), '${v['oilUsageMonths']} bln'),
              if (v['lastOilDate'] != null) _infoChip('last_oil_date'.tr(), DateFormat('dd/MM/yyyy').format(DateTime.parse(v['lastOilDate']))),
              if (v['nextOilDate'] != null) _infoChip('next_oil_date'.tr(), DateFormat('dd/MM/yyyy').format(DateTime.parse(v['nextOilDate']))),
            ])
          ]),
        ),
      ),
    );
  }

  // ------------------ BUILD ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF6A5AE0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        title: Text("vehicle_data".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'export_all'.tr(),
            onPressed: _exportAllToPdf,
            icon: const Icon(Icons.file_download, color: Colors.white),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: const EdgeInsets.all(16),
        child: _vehicles.isEmpty
            ? Center(child: Text("no_data".tr(), style: const TextStyle(color: Colors.white70)))
            : RefreshIndicator(
                onRefresh: _loadVehicles,
                color: const Color(0xFF6A5AE0),
                child: ListView.builder(
                  itemCount: _vehicles.length,
                  itemBuilder: (_, i) => _buildVehicleCard(_vehicles[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6A5AE0),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showVehicleForm(),
      ),
    );
  }
}
