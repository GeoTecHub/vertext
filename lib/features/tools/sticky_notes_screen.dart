import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StickyNote {
  final String id;
  String content;
  int colorValue;
  int timestamp;

  StickyNote({required this.id, required this.content, required this.colorValue, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'colorValue': colorValue,
    'timestamp': timestamp,
  };

  factory StickyNote.fromJson(Map<String, dynamic> json) => StickyNote(
    id: json['id'],
    content: json['content'],
    colorValue: json['colorValue'],
    timestamp: json['timestamp'],
  );
}

class StickyNotesScreen extends StatefulWidget {
  const StickyNotesScreen({super.key});

  @override
  State<StickyNotesScreen> createState() => _StickyNotesScreenState();
}

class _StickyNotesScreenState extends State<StickyNotesScreen> {
  final List<Color> _noteColors = [
    const Color(0xFFFFF740),
    const Color(0xFFFF8A8A),
    const Color(0xFF82C8A0),
    const Color(0xFF74B9FF),
    const Color(0xFFF3A683),
    const Color(0xFFD980FA),
  ];

  List<StickyNote> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('sticky_notes');
    if (notesJson != null) {
      final List<dynamic> decoded = jsonDecode(notesJson);
      _notes = decoded.map((e) => StickyNote.fromJson(e)).toList();
      _notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_notes.map((e) => e.toJson()).toList());
    await prefs.setString('sticky_notes', encoded);
  }

  void _showNoteDialog({StickyNote? note}) {
    final isEditing = note != null;
    final contentController = TextEditingController(text: isEditing ? note.content : '');
    Color selectedColor = isEditing ? Color(note.colorValue) : _noteColors.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Note' : 'New Note'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: contentController,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: 'Type your note here...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: selectedColor.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _noteColors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color ? Colors.black87 : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        _notes.removeWhere((n) => n.id == note.id);
                      });
                      await _saveNotes();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(iconColor: Colors.red, foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty) return;

                    setState(() {
                      if (isEditing) {
                        note.content = content;
                        note.colorValue = selectedColor.value; 
                        note.timestamp = DateTime.now().millisecondsSinceEpoch;
                      } else {
                        _notes.add(StickyNote(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          content: content,
                          colorValue: selectedColor.value,
                          timestamp: DateTime.now().millisecondsSinceEpoch,
                        ));
                      }
                      _notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                    });
                    
                    await _saveNotes();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticky Notes'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildNoteCard(note);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No sticky notes yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first note',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(StickyNote note) {
    final color = Color(note.colorValue);

    return Card(
      elevation: 3,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showNoteDialog(note: note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
