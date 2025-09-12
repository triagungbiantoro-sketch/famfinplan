import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../db/jadwalmingguan_db.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  _JadwalScreenState createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final List<String> hariList = [
    'senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'
  ];

  Map<String, List<Map<String, dynamic>>> jadwalPerHari = {};
  late String selectedHari;
  bool isLoading = true;

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday;
    selectedHari = hariList[weekday - 1];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadJadwal();
    });

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

  Future<void> _loadJadwal() async {
    try {
      setState(() => isLoading = true);

      Map<String, List<Map<String, dynamic>>> temp = {};
      for (var hari in hariList) {
        final data = List<Map<String, dynamic>>.from(
            await JadwalMingguanDB.instance.getJadwalByHari(hari));
        data.sort((a, b) => a['waktu'].compareTo(b['waktu']));
        temp[hari] = data;
      }

      setState(() {
        jadwalPerHari = temp;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error load jadwal: $e');
      _showInfoDialog(tr("gagal"), tr("gagal_memuat_jadwal"));
    }
  }

  Future<void> _deleteJadwal(int id) async {
    try {
      await JadwalMingguanDB.instance.deleteJadwal(id);
      await _loadJadwal();
      _showInfoDialog(tr("berhasil"), tr("jadwal_berhasil_dihapus"));
    } catch (e) {
      debugPrint('Error delete jadwal: $e');
      _showInfoDialog(tr("gagal"), tr("gagal_menghapus_jadwal"));
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> jadwal) async {
    try {
      int newStatus = jadwal['status'] == 0 ? 1 : 0;
      await JadwalMingguanDB.instance.updateJadwal(jadwal['id'], {
        'hari': jadwal['hari'],
        'waktu': jadwal['waktu'],
        'kegiatan': jadwal['kegiatan'],
        'status': newStatus,
      });
      await _loadJadwal();
    } catch (e) {
      debugPrint('Error toggle status: $e');
      _showInfoDialog(tr("gagal"), tr("gagal_perbarui_status"));
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context), child: Text(tr("ok")))
        ],
      ),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? jadwal}) {
    _showInterstitialAd(); // tampilkan ad saat membuka dialog add/edit

    String selectedHariDialog = jadwal?['hari'] ?? selectedHari;
    TextEditingController kegiatanController =
        TextEditingController(text: jadwal?['kegiatan'] ?? '');
    TimeOfDay selectedTime = jadwal != null
        ? TimeOfDay(
            hour: int.parse(jadwal['waktu'].split(":")[0]),
            minute: int.parse(jadwal['waktu'].split(":")[1]))
        : TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(jadwal == null ? tr("tambah_jadwal") : tr("edit_jadwal"),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedHariDialog,
                items: hariList
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(tr(e)),
                        ))
                    .toList(),
                onChanged: (val) {
                  setStateDialog(() => selectedHariDialog = val!);
                },
                decoration: InputDecoration(
                  labelText: tr("hari"),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: kegiatanController,
                decoration: InputDecoration(
                  labelText: tr("kegiatan"),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final time = await showTimePicker(
                      context: context, initialTime: selectedTime);
                  if (time != null) setStateDialog(() => selectedTime = time);
                },
                icon: const Icon(Icons.access_time),
                label: Text(tr("pilih_waktu")),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Text('${tr("waktu")}: ${selectedTime.format(context)}'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: Text(tr("batal"))),
            ElevatedButton(
                onPressed: () async {
                  if (kegiatanController.text.trim().isEmpty) return;

                  final data = {
                    'hari': selectedHariDialog,
                    'waktu':
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    'kegiatan': kegiatanController.text.trim(),
                    'status': jadwal?['status'] ?? 0,
                  };

                  try {
                    if (jadwal == null) {
                      await JadwalMingguanDB.instance.insertJadwal(data);
                    } else {
                      await JadwalMingguanDB.instance
                          .updateJadwal(jadwal['id'], data);
                    }
                    Navigator.pop(context);
                    await _loadJadwal();
                    _showInfoDialog(
                        tr("berhasil"),
                        jadwal == null
                            ? tr("jadwal_berhasil_disimpan")
                            : tr("jadwal_berhasil_diperbarui"));
                  } catch (e) {
                    Navigator.pop(context);
                    _showInfoDialog(
                        tr("gagal"),
                        jadwal == null
                            ? tr("gagal_menyimpan_jadwal")
                            : tr("gagal_memperbarui_jadwal"));
                    debugPrint('Error save/update jadwal: $e');
                  }
                },
                child: Text(tr("simpan"))),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> jadwal, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: jadwal['status'] == 1
                    ? const LinearGradient(
                        colors: [Colors.greenAccent, Colors.green])
                    : const LinearGradient(
                        colors: [Colors.grey, Colors.grey]),
              ),
              child: Icon(
                jadwal['status'] == 1 ? Icons.check : Icons.circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Text(jadwal['kegiatan'],
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: Text('${tr(jadwal['hari'])}, ${jadwal['waktu']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showAddEditDialog(jadwal: jadwal)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              title: Text(tr("konfirmasi_hapus")),
                              content: Text(tr("hapus_jadwal_ini")),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(tr("batal"))),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteJadwal(jadwal['id']);
                                  },
                                  child: Text(tr("hapus")),
                                )
                              ],
                            ),
                          )),
                ],
              ),
              leading: IconButton(
                icon: Icon(
                  jadwal['status'] == 1
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: jadwal['status'] == 1 ? Colors.green : Colors.grey,
                  size: 28,
                ),
                onPressed: () => _toggleStatus(jadwal),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final jadwalList = jadwalPerHari[selectedHari] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr("jadwal_mingguan"),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1768AC),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedHari,
                    items: hariList
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(tr(e)),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      setState(() => selectedHari = val!);
                      await _loadJadwal();
                    },
                    decoration: InputDecoration(
                      labelText: tr("pilih_hari"),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: jadwalList.isEmpty
                      ? Center(
                          child: Text(tr("no_data"),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ListView.builder(
                            itemCount: jadwalList.length,
                            itemBuilder: (context, index) {
                              final jadwal = jadwalList[index];
                              final isLast = index == jadwalList.length - 1;
                              return _buildTimelineCard(jadwal, isLast);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: Text(tr("tambah_jadwal")),
      ),
    );
  }
}
