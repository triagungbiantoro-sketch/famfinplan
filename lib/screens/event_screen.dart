import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // <-- import AdMob
import '../db/event_db.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late Future<List<Event>> _eventList;

  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _refreshEvents();
    _loadInterstitialAd();
  }

  void _refreshEvents() {
    setState(() {
      _eventList = EventDatabase.instance.getAllEvents();
    });
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // <-- ganti dengan ID AdMob Anda
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load interstitial ad: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // load ad berikutnya
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

  Future<void> _showEventForm({Event? event}) async {
    // Tampilkan interstitial saat buka form
    _showInterstitialAd();

    final titleController = TextEditingController(text: event?.title ?? "");
    final descController = TextEditingController(text: event?.description ?? "");
    final categoryController = TextEditingController(text: event?.category ?? "");
    DateTime selectedDate = event?.eventDate ?? DateTime.now();
    int priority = event?.priority ?? 2;
    int reminderMinutes = event?.reminderMinutes ?? 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          event == null ? "Tambah Event" : "Edit Event",
          style: const TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Judul",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                ),
              ),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Deskripsi",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                ),
              ),
              TextField(
                controller: categoryController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    },
                    child: Text(
                      DateFormat('dd MMM yyyy').format(selectedDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            picked.hour,
                            picked.minute,
                          );
                        });
                      }
                    },
                    child: Text(
                      DateFormat('HH:mm').format(selectedDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: priority,
                dropdownColor: Colors.black,
                decoration: const InputDecoration(
                  labelText: "Prioritas",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                ),
                items: [
                  DropdownMenuItem(value: 1, child: Text("Rendah", style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 2, child: Text("Sedang", style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 3, child: Text("Tinggi", style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) {
                  priority = val ?? 2;
                },
              ),
              TextField(
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: reminderMinutes.toString()),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Reminder (menit sebelum)",
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                ),
                onChanged: (val) {
                  reminderMinutes = int.tryParse(val) ?? 0;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Batal", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text("Simpan"),
            onPressed: () async {
              if (titleController.text.isEmpty) return;

              final newEvent = Event(
                id: event?.id,
                title: titleController.text,
                description: descController.text,
                category: categoryController.text,
                eventDate: selectedDate,
                priority: priority,
                isCompleted: event?.isCompleted ?? false,
                reminderMinutes: reminderMinutes,
              );

              if (event == null) {
                await EventDatabase.instance.createEvent(newEvent);
              } else {
                await EventDatabase.instance.updateEvent(newEvent);
              }
              Navigator.pop(context);
              _refreshEvents();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(int priority) {
    Color bgColor;
    String text;

    switch (priority) {
      case 1:
        bgColor = Colors.greenAccent.shade400;
        text = "Rendah";
        break;
      case 2:
        bgColor = Colors.orangeAccent.shade400;
        text = "Sedang";
        break;
      case 3:
        bgColor = Colors.redAccent.shade400;
        text = "Tinggi";
        break;
      default:
        bgColor = Colors.grey;
        text = "Unknown";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.7),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Event",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<Event>>(
        future: _eventList,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Center(
              child: Text(
                "Belum ada event",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final e = events[index];
              return Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(
                      e.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: e.isCompleted ? Colors.green : Colors.white70,
                    ),
                    onPressed: () async {
                      final updated = Event(
                        id: e.id,
                        title: e.title,
                        description: e.description,
                        category: e.category,
                        eventDate: e.eventDate,
                        priority: e.priority,
                        isCompleted: !e.isCompleted,
                        reminderMinutes: e.reminderMinutes,
                      );
                      await EventDatabase.instance.updateEvent(updated);
                      _refreshEvents();
                    },
                  ),
                  title: Text(
                    e.title,
                    style: TextStyle(
                      color: e.isCompleted ? Colors.grey : Colors.white,
                      decoration: e.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.description,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        "${DateFormat('dd MMM yyyy HH:mm').format(e.eventDate)} | ${e.category}",
                        style: const TextStyle(color: Colors.cyanAccent),
                      ),
                      const SizedBox(height: 4),
                      _buildPriorityChip(e.priority),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.cyanAccent),
                        onPressed: () => _showEventForm(event: e),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          await EventDatabase.instance.deleteEvent(e.id!);
                          _refreshEvents();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => _showEventForm(),
      ),
    );
  }
}
