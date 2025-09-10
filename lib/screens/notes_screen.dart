import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/notes_database.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();
  final Map<int, bool> _expandedMap = {};
  final ScrollController _scrollController = ScrollController();
  final Color _primaryColor = Colors.blue[800]!;

  int _currentPage = 0;
  final int _itemsPerPage = 4;

  @override
  void initState() {
    super.initState();
    _refreshNotes();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _refreshNotes({bool scrollToFirst = true}) async {
    final data = await NotesDatabase.instance.getAllNotes();
    setState(() {
      _notes = data.reversed.toList();
      _filteredNotes = _notes;
      _expandedMap.clear();
      _currentPage = 0;

      if (scrollToFirst) _scrollToTop();
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes.where((note) {
        final title = (note['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
      _currentPage = 0;
      _scrollToTop();
    });
  }

  Future<void> _showNoteDialog({Map<String, dynamic>? note}) async {
    final titleController = TextEditingController(text: note?['title'] ?? '');
    final contentController = TextEditingController(text: note?['content'] ?? '');
    XFile? imageFile;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text(note == null ? 'add_note'.tr() : 'edit_note'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'title'.tr()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(labelText: 'content'.tr()),
                  keyboardType: TextInputType.multiline,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (picked != null) setStateDialog(() => imageFile = picked);
                      },
                      icon: const Icon(Icons.photo),
                      label: Text('gallery'.tr()),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                        if (picked != null) setStateDialog(() => imageFile = picked);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: Text('camera'.tr()),
                    ),
                  ],
                ),
                if (imageFile?.path != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Image.file(File(imageFile!.path), height: 100),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now();
                final newNote = {
                  'title': titleController.text,
                  'content': contentController.text,
                  'date': note?['date'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
                  'imagePath': imageFile?.path ?? note?['imagePath'],
                };

                if (note == null) {
                  await NotesDatabase.instance.insertNote(newNote);
                  _refreshNotes(scrollToFirst: true);
                } else {
                  newNote['id'] = note['id'];
                  await NotesDatabase.instance.updateNote(newNote);
                  _refreshNotes(scrollToFirst: false);
                }

                Navigator.pop(context);
              },
              child: Text('save'.tr()),
            ),
          ],
        );
      }),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  void _shareNote(Map<String, dynamic> note) {
    String text =
        '${'title_label'.tr()}: ${note['title'] ?? ''}\n${'date_label'.tr()}: ${_formatDate(note['date'])}\n${'content_label'.tr()}: ${note['content'] ?? ''}';
    final imagePath = note['imagePath'] as String?;
    if (imagePath?.isNotEmpty ?? false) {
      Share.shareXFiles([XFile(imagePath!)], text: text);
    } else {
      Share.share(text);
    }
  }

  void _shareAllNotes() {
    String allNotes = _notes.map((n) {
      return '${'title_label'.tr()}: ${n['title'] ?? ''}\n${'date_label'.tr()}: ${_formatDate(n['date'])}\n${'content_label'.tr()}: ${n['content'] ?? ''}';
    }).join('\n\n---\n\n');

    final List<XFile> files = _notes
        .where((n) => (n['imagePath'] as String?)?.isNotEmpty ?? false)
        .map((n) => XFile(n['imagePath']!))
        .toList();

    if (files.isNotEmpty) {
      Share.shareXFiles(files, text: allNotes);
    } else {
      Share.share(allNotes);
    }
  }

  void _exportNotesToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => _notes.map((note) {
          final List<pw.Widget> contentWidgets = [
            pw.Text('${'title_label'.tr()}: ${note['title'] ?? ''}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('${'date_label'.tr()}: ${_formatDate(note['date'])}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.SizedBox(height: 5),
            pw.Text('${'content_label'.tr()}: ${note['content'] ?? ''}'),
          ];

          final imagePath = note['imagePath'] as String?;
          if (imagePath?.isNotEmpty ?? false) {
            contentWidgets.add(pw.SizedBox(height: 8));
            final file = File(imagePath!);
            if (file.existsSync()) {
              final image = pw.MemoryImage(file.readAsBytesSync());
              contentWidgets.add(pw.Image(image, width: 200, height: 200));
            }
          }

          contentWidgets.add(pw.Divider());

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: contentWidgets,
          );
        }).toList(),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  List<Map<String, dynamic>> _getCurrentPageItems() {
    int start = _currentPage * _itemsPerPage;
    int end = start + _itemsPerPage;
    if (start > _filteredNotes.length) start = _filteredNotes.length;
    if (end > _filteredNotes.length) end = _filteredNotes.length;
    return _filteredNotes.sublist(start, end);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentItems = _getCurrentPageItems();
    int totalPages = ((_filteredNotes.length - 1) ~/ _itemsPerPage) + 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('notes'.tr(), style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareAllNotes, color: Colors.white),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportNotesToPDF, color: Colors.white),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_notes'.tr(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: currentItems.isEmpty
                ? Center(child: Text('no_notes'.tr()))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: currentItems.length,
                    itemBuilder: (_, index) {
                      final note = currentItems[index];
                      final globalIndex = index + _currentPage * _itemsPerPage;
                      final isExpanded = _expandedMap[globalIndex] ?? false;
                      final imagePath = note['imagePath'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _expandedMap[globalIndex] = !isExpanded),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    note['title'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${'date_label'.tr()}: ${_formatDate(note['date'])}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (isExpanded) ...[
                                  const SizedBox(height: 8),
                                  Text(note['content'] ?? '', style: const TextStyle(fontSize: 14)),
                                  if (imagePath?.isNotEmpty ?? false)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Image.file(File(imagePath!), height: 100),
                                    ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      color: _primaryColor,
                                      onPressed: () => _shareNote(note),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      color: Colors.orange,
                                      onPressed: () => _showNoteDialog(note: note),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () async {
                                        await NotesDatabase.instance.deleteNote(note['id']);
                                        _refreshNotes();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_filteredNotes.length > _itemsPerPage)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() => _currentPage--);
                            _scrollToTop();
                          }
                        : null,
                    child: Text('previous'.tr()),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'page_label'.tr(args: ['${_currentPage + 1}', '$totalPages']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: (_currentPage + 1) * _itemsPerPage < _filteredNotes.length
                        ? () {
                            setState(() => _currentPage++);
                            _scrollToTop();
                          }
                        : null,
                    child: Text('next'.tr()),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () => _showNoteDialog(),
      ),
    );
  }
}
