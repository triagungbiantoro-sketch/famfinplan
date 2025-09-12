import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _refreshNotes();
    _searchController.addListener(_onSearchChanged);

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Ad Unit ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('Failed to load a banner ad: ${err.message}');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );
    _bannerAd.load();
  }

  Future<void> _refreshNotes({bool scrollToFirst = true}) async {
    try {
      final data = await NotesDatabase.instance.getAllNotes();
      setState(() {
        _notes = data;
        _filteredNotes = _notes;
        _expandedMap.clear();
        _currentPage = 0;
        if (scrollToFirst) _scrollToTop();
      });
    } catch (e) {
      print('Error refreshing notes: $e');
    }
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
    final query = _searchController.text.toLowerCase();
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
    XFile? imageFile = note != null && note['imagePath'] != null && note['imagePath'].isNotEmpty
        ? XFile(note['imagePath'])
        : null;

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
                final title = titleController.text.trim();
                final content = contentController.text.trim();

                if (title.isEmpty && content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('note_empty_error'.tr())),
                  );
                  return;
                }

                final now = DateTime.now();
                final newNote = {
                  'title': title,
                  'content': content,
                  'date': note == null
                      ? DateFormat('yyyy-MM-dd HH:mm:ss').format(now)
                      : note['date'],
                  'imagePath': imageFile?.path ?? note?['imagePath'],
                };

                try {
                  if (note == null) {
                    await NotesDatabase.instance.insertNote(newNote);
                  } else {
                    newNote['id'] = note['id'];
                    await NotesDatabase.instance.updateNote(newNote);
                  }
                  await _refreshNotes(scrollToFirst: true);
                  Navigator.pop(context);
                } catch (e) {
                  print('Error saving note: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('save_failed'.tr())),
                  );
                }
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

  void _shareNoteWithOptions(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text('Share as PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _shareNoteAsPDF(note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: Text('Share as Text'),
                onTap: () {
                  Navigator.pop(context);
                  _shareNoteAsText(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareNoteAsText(Map<String, dynamic> note) {
    String text =
        '${'title_label'.tr()}: ${note['title'] ?? ''}\n${'date_label'.tr()}: ${_formatDate(note['date'])}\n${'content_label'.tr()}: ${note['content'] ?? ''}';
    final imagePath = note['imagePath'] as String?;
    if (imagePath?.isNotEmpty ?? false) {
      Share.shareXFiles([XFile(imagePath!)], text: text);
    } else {
      Share.share(text);
    }
  }

  void _shareNoteAsPDF(Map<String, dynamic> note) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final List<pw.Widget> contentWidgets = [
            pw.Text('${'title_label'.tr()}: ${note['title'] ?? ''}',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('${'date_label'.tr()}: ${_formatDate(note['date'])}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.SizedBox(height: 12),
            pw.Text('${'content_label'.tr()}: ${note['content'] ?? ''}', style: pw.TextStyle(fontSize: 14)),
          ];

          final imagePath = note['imagePath'] as String?;
          if (imagePath != null && imagePath.isNotEmpty) {
            final file = File(imagePath);
            if (file.existsSync()) {
              final image = pw.MemoryImage(file.readAsBytesSync());
              contentWidgets.add(pw.SizedBox(height: 12));
              contentWidgets.add(pw.Image(image, width: 200, height: 200));
            }
          }

          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: contentWidgets);
        },
      ),
    );

    final outputDir = Directory.systemTemp;
    final file = File('${outputDir.path}/note_${note['id'] ?? DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Note PDF');
  }

  void _shareAllNotes() async {
    if (_notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_notes_to_share'.tr())),
      );
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text('notes'.tr(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
        ),
        build: (context) => _notes.map((note) {
          final List<pw.Widget> contentWidgets = [
            pw.Text('${'title_label'.tr()}: ${note['title'] ?? ''}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('${'date_label'.tr()}: ${_formatDate(note['date'])}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            pw.SizedBox(height: 8),
            pw.Text('${'content_label'.tr()}: ${note['content'] ?? ''}', style: pw.TextStyle(fontSize: 14)),
          ];

          final imagePath = note['imagePath'] as String?;
          if (imagePath != null && imagePath.isNotEmpty) {
            final file = File(imagePath);
            if (file.existsSync()) {
              final image = pw.MemoryImage(file.readAsBytesSync());
              contentWidgets.add(pw.SizedBox(height: 8));
              contentWidgets.add(pw.Image(image, width: 200, height: 200));
            }
          }

          contentWidgets.add(pw.Divider(height: 20));
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: contentWidgets);
        }).toList(),
      ),
    );

    final outputDir = Directory.systemTemp;
    final file = File('${outputDir.path}/notes_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Notes PDF');
  }

  List<Map<String, dynamic>> _getCurrentPageItems() {
    int start = _currentPage * _itemsPerPage;
    int end = start + _itemsPerPage;
    if (start > _filteredNotes.length) start = _filteredNotes.length;
    if (end > _filteredNotes.length) end = _filteredNotes.length;
    return _filteredNotes.sublist(start, end);
  }

  Future<void> _confirmDelete(Map<String, dynamic> note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'.tr()),
        content: Text('delete_note_confirmation'.tr(args: [note['title'] ?? ''])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotesDatabase.instance.deleteNote(note['id']);
      await _refreshNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('note_deleted'.tr())),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _bannerAd.dispose();
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
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _shareAllNotes, color: Colors.white),
        ],
      ),
      body: Column(
        children: [
          if (_isBannerAdReady)
            SizedBox(
              width: _bannerAd.size.width.toDouble(),
              height: _bannerAd.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd),
            ),
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
                                    note['title'] ?? 'No Title',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDate(note['date']),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                if (isExpanded) ...[
                                  const SizedBox(height: 8),
                                  Text(note['content'] ?? ''),
                                  if (imagePath != null && imagePath.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => Scaffold(
                                                backgroundColor: Colors.black,
                                                appBar: AppBar(
                                                  backgroundColor: Colors.transparent,
                                                  elevation: 0,
                                                  iconTheme: const IconThemeData(color: Colors.white),
                                                ),
                                                body: Center(
                                                  child: InteractiveViewer(
                                                    child: Image.file(File(imagePath)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Image.file(
                                          File(imagePath),
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        onPressed: () => _showNoteDialog(note: note),
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                      ),
                                      IconButton(
                                        onPressed: () => _confirmDelete(note),
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                      ),
                                      IconButton(
                                        onPressed: () => _shareNoteWithOptions(note),
                                        icon: const Icon(Icons.share),
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text('${_currentPage + 1} / $totalPages'),
                  IconButton(
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: () => _showNoteDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
