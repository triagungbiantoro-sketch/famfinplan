import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../db/event_db.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _refreshEvents();
  }

  Future<void> _refreshEvents() async {
    final events = await EventDatabase.instance.getAllEvents();
    setState(() {
      _events = events;
    });
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _isUpcoming(DateTime date) {
    final now = DateTime.now();
    return date.isAfter(now) && date.isBefore(now.add(const Duration(hours: 24)));
  }

  Future<void> _showEventDialog({Event? event}) async {
    final _titleController = TextEditingController(text: event?.title ?? '');
    final _descController = TextEditingController(text: event?.description ?? '');
    final _categoryController = TextEditingController(text: event?.category ?? '');
    DateTime _eventDate = event?.eventDate ?? DateTime.now();
    int _priority = event?.priority ?? 2;
    int _reminder = event?.reminderMinutes ?? 0;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(event == null ? 'Tambah Event' : 'Edit Event',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                // Description
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // Category
                TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                // Date & Time
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _eventDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _eventDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _eventDate.hour,
                              _eventDate.minute,
                            );
                          });
                        }
                      },
                      child: Text(DateFormat('yyyy-MM-dd').format(_eventDate)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_eventDate),
                        );
                        if (picked != null) {
                          setState(() {
                            _eventDate = DateTime(
                              _eventDate.year,
                              _eventDate.month,
                              _eventDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Priority
                Row(
                  children: [
                    const Text('Priority: '),
                    DropdownButton<int>(
                      value: _priority,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Low')),
                        DropdownMenuItem(value: 2, child: Text('Medium')),
                        DropdownMenuItem(value: 3, child: Text('High')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _priority = val);
                      },
                    ),
                  ],
                ),
                // Reminder
                Row(
                  children: [
                    const Text('Reminder: '),
                    DropdownButton<int>(
                      value: _reminder,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('None')),
                        DropdownMenuItem(value: 5, child: Text('5 min before')),
                        DropdownMenuItem(value: 10, child: Text('10 min before')),
                        DropdownMenuItem(value: 30, child: Text('30 min before')),
                        DropdownMenuItem(value: 60, child: Text('1 hour before')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _reminder = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final newEvent = Event(
                  id: event?.id,
                  title: _titleController.text,
                  description: _descController.text,
                  category: _categoryController.text,
                  eventDate: _eventDate,
                  priority: _priority,
                  reminderMinutes: _reminder,
                );

                if (event != null && event.id != null) {
                  await NotificationService.instance.cancelNotification(event.id!);
                  await EventDatabase.instance.updateEvent(newEvent);
                } else {
                  final id = await EventDatabase.instance.createEvent(newEvent);
                  newEvent.id = id;
                }

                if (newEvent.reminderMinutes > 0 && newEvent.id != null) {
                  final scheduledTime = newEvent.eventDate.subtract(
                    Duration(minutes: newEvent.reminderMinutes),
                  );
                  if (scheduledTime.isAfter(DateTime.now())) {
                    await NotificationService.instance.scheduleNotification(
                      newEvent.id!,
                      newEvent.title,
                      newEvent.description,
                      scheduledTime,
                    );
                  }
                }

                Navigator.pop(context);
                _refreshEvents();
              },
              child: Text(event == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(Event event) async {
    if (event.id != null) {
      await NotificationService.instance.cancelNotification(event.id!);
      await EventDatabase.instance.deleteEvent(event.id!);
      _refreshEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent,
      ),
      body: _events.isEmpty
          ? const Center(
              child: Text(
                'No events yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _events.length,
              itemBuilder: (_, index) {
                final e = _events[index];
                final isUpcoming = _isUpcoming(e.eventDate);

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 6,
                  color: isUpcoming ? Colors.yellow[50] : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Icon(Icons.event_note,
                            size: 36, color: _priorityColor(e.priority)),
                        if (e.reminderMinutes > 0)
                          const Icon(Icons.notifications_active,
                              size: 16, color: Colors.redAccent),
                      ],
                    ),
                    title: Text(e.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(e.description),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: _priorityColor(e.priority),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                ['Low', 'Medium', 'High'][e.priority - 1],
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (e.category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.blueGrey,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  e.category,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(e.eventDate) +
                              (e.reminderMinutes > 0
                                  ? ' • Reminder: ${e.reminderMinutes} min'
                                  : ''),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _showEventDialog(event: e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteEvent(e),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
