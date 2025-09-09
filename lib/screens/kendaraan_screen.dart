import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';
import '../services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:excel/excel.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _lastOilChangeKmController = TextEditingController();
  final TextEditingController _oilUsageMonthsController = TextEditingController();

  DateTime? _taxDate;
  DateTime? _lastOilChangeDate;
  DateTime? _nextOilDate;
  DateTime? _reminderDateTime;
  int? _editingVehicleId;

  final List<String> _vehicleTypes = ['Sepeda Motor / Motorcycle', 'Mobil / Car'];
  Future<List<Map<String, dynamic>>>? _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _vehiclesFuture = DatabaseHelper.instance.getVehicles();
  }

  String _formatDate(String? isoDate, {bool includeTime = false}) {
    if (isoDate == null) return '-';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '-';
    return includeTime
        ? DateFormat('dd/MM/yyyy HH:mm').format(date)
        : DateFormat('dd/MM/yyyy').format(date);
  }

  void _refreshVehicles() {
    setState(() {
      _vehiclesFuture = DatabaseHelper.instance.getVehicles();
    });
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _vehicleTypeController.clear();
    _plateNumberController.clear();
    _lastOilChangeKmController.clear();
    _oilUsageMonthsController.clear();
    _taxDate = null;
    _lastOilChangeDate = null;
    _nextOilDate = null;
    _reminderDateTime = null;
    _editingVehicleId = null;
  }

  void _calculateNextOilDate() {
    if (_lastOilChangeDate != null && _oilUsageMonthsController.text.isNotEmpty) {
      final months = int.tryParse(_oilUsageMonthsController.text) ?? 0;
      _nextOilDate = DateTime(
        _lastOilChangeDate!.year,
        _lastOilChangeDate!.month + months,
        _lastOilChangeDate!.day,
      );
    }
  }

  void _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_taxDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_tax_date'.tr())),
      );
      return;
    }

    _calculateNextOilDate();

    final vehicleData = {
      'vehicleType': _vehicleTypeController.text,
      'plateNumber': _plateNumberController.text,
      'taxDate': _taxDate!.toIso8601String(),
      'lastOilKm': int.parse(_lastOilChangeKmController.text),
      'oilUsageMonths': int.parse(_oilUsageMonthsController.text),
      'lastOilChangeDate': _lastOilChangeDate?.toIso8601String(),
      'nextOilDate': _nextOilDate?.toIso8601String(),
      'reminderDateTime': _reminderDateTime?.toIso8601String(),
    };

    if (_editingVehicleId == null) {
      await DatabaseHelper.instance.insertVehicle(vehicleData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('vehicle_saved'.tr())),
      );
    } else {
      await DatabaseHelper.instance.updateVehicle(_editingVehicleId!, vehicleData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('vehicle_updated'.tr())),
      );
    }

    if (_reminderDateTime != null) {
      await NotificationService.instance.scheduleNotification(
        _editingVehicleId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Pengingat Kendaraan',
        'Waktunya periksa/mengganti oli: ${_vehicleTypeController.text} - ${_plateNumberController.text}',
        _reminderDateTime!,
      );
    }

    _clearForm();
    _refreshVehicles();
  }

  void _editVehicle(Map<String, dynamic> vehicle) {
    if (vehicle == null) return;

    _editingVehicleId = vehicle['id'] as int?;

    _vehicleTypeController.text = vehicle['vehicleType'] ?? '';
    _plateNumberController.text = vehicle['plateNumber'] ?? '';
    _lastOilChangeKmController.text = vehicle['lastOilKm']?.toString() ?? '';
    _oilUsageMonthsController.text = vehicle['oilUsageMonths']?.toString() ?? '';

    final taxDateStr = vehicle['taxDate'] as String?;
    final lastOilStr = vehicle['lastOilChangeDate'] as String?;
    final nextOilStr = vehicle['nextOilDate'] as String?;
    final reminderStr = vehicle['reminderDateTime'] as String?;

    _taxDate = taxDateStr != null ? DateTime.tryParse(taxDateStr) : null;
    _lastOilChangeDate = lastOilStr != null ? DateTime.tryParse(lastOilStr) : null;
    _nextOilDate = nextOilStr != null ? DateTime.tryParse(nextOilStr) : null;
    _reminderDateTime = reminderStr != null ? DateTime.tryParse(reminderStr) : null;
  }

  Future<void> _shareVehicleText(Map<String, dynamic> v) async {
    final vehicleInfo = '''
${v['vehicleType']} - ${v['plateNumber']}
${'tax_date'.tr()}: ${_formatDate(v['taxDate'])}
${'last_oil_km'.tr()}: ${v['lastOilKm']}
${'oil_usage_months'.tr()}: ${v['oilUsageMonths']}
${'last_oil_change_date'.tr()}: ${_formatDate(v['lastOilChangeDate'])}
${'next_oil_date'.tr()}: ${_formatDate(v['nextOilDate'])}
${'reminder'.tr()}: ${_formatDate(v['reminderDateTime'], includeTime: true)}
''';
    await Share.share(vehicleInfo);
  }

  Future<void> _shareVehiclePDF(Map<String, dynamic> v) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${v['vehicleType']} - ${v['plateNumber']}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('${'tax_date'.tr()}: ${_formatDate(v['taxDate'])}'),
              pw.Text('${'last_oil_km'.tr()}: ${v['lastOilKm']}'),
              pw.Text('${'oil_usage_months'.tr()}: ${v['oilUsageMonths']}'),
              pw.Text('${'last_oil_change_date'.tr()}: ${_formatDate(v['lastOilChangeDate'])}'),
              pw.Text('${'next_oil_date'.tr()}: ${_formatDate(v['nextOilDate'])}'),
              pw.Text('${'reminder'.tr()}: ${_formatDate(v['reminderDateTime'], includeTime: true)}'),
            ],
          );
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/vehicle_${v['id']}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Vehicle Info PDF');
  }

  Future<void> _shareAllVehiclesPDF(List<Map<String, dynamic>> vehicles) async {
    final pdf = pw.Document();
    for (var v in vehicles) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${v['vehicleType']} - ${v['plateNumber']}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('${'tax_date'.tr()}: ${_formatDate(v['taxDate'])}'),
                pw.Text('${'last_oil_km'.tr()}: ${v['lastOilKm']}'),
                pw.Text('${'oil_usage_months'.tr()}: ${v['oilUsageMonths']}'),
                pw.Text('${'last_oil_change_date'.tr()}: ${_formatDate(v['lastOilChangeDate'])}'),
                pw.Text('${'next_oil_date'.tr()}: ${_formatDate(v['nextOilDate'])}'),
                pw.Text('${'reminder'.tr()}: ${_formatDate(v['reminderDateTime'], includeTime: true)}'),
              ],
            );
          },
        ),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/all_vehicles.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'All Vehicles PDF');
  }

  Future<void> _shareAllVehiclesExcel(List<Map<String, dynamic>> vehicles) async {
    final excel = Excel.createExcel();
    final sheet = excel['Vehicles'];

    sheet.appendRow([
      'Vehicle Type',
      'Plate Number',
      'Tax Date',
      'Last Oil KM',
      'Oil Usage Months',
      'Last Oil Change Date',
      'Next Oil Date',
      'Reminder'
    ]);

    for (var v in vehicles) {
      sheet.appendRow([
        v['vehicleType'],
        v['plateNumber'],
        _formatDate(v['taxDate']),
        v['lastOilKm'],
        v['oilUsageMonths'],
        _formatDate(v['lastOilChangeDate']),
        _formatDate(v['nextOilDate']),
        _formatDate(v['reminderDateTime'], includeTime: true),
      ]);
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/all_vehicles.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(file.path)], text: 'All Vehicles Excel');
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _buildDatePickerField(String label, DateTime? selectedDate, Function(DateTime) onDateSelected) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateSelected(picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Text(
          selectedDate == null ? 'select_date'.tr() : DateFormat('dd/MM/yyyy').format(selectedDate),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDateTimePickerField(String label, DateTime? selectedDateTime, Function(DateTime) onDateTimeSelected) {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDateTime ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: selectedDateTime != null
                ? TimeOfDay(hour: selectedDateTime.hour, minute: selectedDateTime.minute)
                : TimeOfDay.now(),
          );
          if (pickedTime != null) {
            final dateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            onDateTimeSelected(dateTime);
          }
        }
      },
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Text(
          selectedDateTime == null
              ? 'select_date_time'.tr()
              : DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('vehicle_info'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _vehicleTypes.contains(_vehicleTypeController.text)
                  ? _vehicleTypeController.text
                  : null,
              items: _vehicleTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _vehicleTypeController.text = val ?? ''),
              validator: (val) =>
                  val == null || val.isEmpty ? 'select_vehicle_type'.tr() : null,
              decoration: _inputDecoration('vehicle_type'.tr()),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _plateNumberController,
              decoration: _inputDecoration('plate_number'.tr()),
              style: const TextStyle(fontSize: 13),
              validator: (val) =>
                  val == null || val.isEmpty ? 'enter_plate_number'.tr() : null,
            ),
            const SizedBox(height: 10),
            _buildDatePickerField('tax_date'.tr(), _taxDate, (date) => setState(() => _taxDate = date)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _lastOilChangeKmController,
              decoration: _inputDecoration('last_oil_km'.tr()),
              keyboardType: TextInputType.number,
              validator: (val) =>
                  val == null || val.isEmpty ? 'enter_last_oil_km'.tr() : null,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _oilUsageMonthsController,
              decoration: _inputDecoration('oil_usage_months'.tr()),
              keyboardType: TextInputType.number,
              validator: (val) =>
                  val == null || val.isEmpty ? 'enter_oil_usage_months'.tr() : null,
              onChanged: (_) => setState(() => _calculateNextOilDate()),
            ),
            const SizedBox(height: 6),
            _buildDatePickerField('last_oil_change_date'.tr(), _lastOilChangeDate, (date) {
              setState(() {
                _lastOilChangeDate = date;
                _calculateNextOilDate();
              });
            }),
            const SizedBox(height: 6),
            _buildDatePickerField('next_oil_date'.tr(), _nextOilDate, (_) {}),
            const SizedBox(height: 6),
            _buildDateTimePickerField('reminder'.tr(), _reminderDateTime, (dateTime) {
              setState(() => _reminderDateTime = dateTime);
            }),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  _saveVehicle();
                  Navigator.pop(context);
                },
                child: Text(
                  _editingVehicleId == null ? 'add'.tr() : 'update'.tr(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCards() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _vehiclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('no_vehicles'.tr()));
        }

        final vehicles = snapshot.data!;
        return Column(
          children: vehicles.map((v) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${v['vehicleType']} - ${v['plateNumber']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${'tax_date'.tr()}: ${_formatDate(v['taxDate'])}', style: const TextStyle(fontSize: 12)),
                    Text('${'last_oil_km'.tr()}: ${v['lastOilKm']}', style: const TextStyle(fontSize: 12)),
                    Text('${'oil_usage_months'.tr()}: ${v['oilUsageMonths']}', style: const TextStyle(fontSize: 12)),
                    Text('${'last_oil_change_date'.tr()}: ${_formatDate(v['lastOilChangeDate'])}', style: const TextStyle(fontSize: 12)),
                    Text('${'next_oil_date'.tr()}: ${_formatDate(v['nextOilDate'])}', style: const TextStyle(fontSize: 12)),
                    Text('${'reminder'.tr()}: ${_formatDate(v['reminderDateTime'], includeTime: true)}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _editVehicle(v);
                            _showVehicleFormSheet();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance.deleteVehicle(v['id']);
                            _refreshVehicles();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                          onPressed: () => _shareVehiclePDF(v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.orange),
                          onPressed: () => _shareVehicleText(v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showVehicleFormSheet() {
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
        child: _buildFormCard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('vehicle'.tr(), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0066FF),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVehicleCards(),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'addVehicle',
            onPressed: () {
              _clearForm();
              _showVehicleFormSheet();
            },
            backgroundColor: const Color(0xFF0066FF),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'shareAll',
            onPressed: () async {
              final vehicles = await DatabaseHelper.instance.getVehicles();
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: Text('Share All as PDF'),
                      onTap: () {
                        Navigator.pop(context);
                        _shareAllVehiclesPDF(vehicles);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.grid_on),
                      title: Text('Share All as Excel'),
                      onTap: () {
                        Navigator.pop(context);
                        _shareAllVehiclesExcel(vehicles);
                      },
                    ),
                  ],
                ),
              );
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
