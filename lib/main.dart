import 'package:NoteIt/components/settings_menu.dart';
import 'package:NoteIt/components/side_bar.dart';
import 'package:NoteIt/components/fake_native_window_bar.dart';
import 'package:flutter/material.dart';
import 'package:NoteIt/utils/auto_debounce.dart';
import 'package:NoteIt/utils/misc.dart';
import 'package:NoteIt/utils/file_utils.dart';
import 'package:NoteIt/note.dart';
import 'package:window_manager/window_manager.dart';

final autoSave = AutoDebouncer();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    title: "Flutter Notes",
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(
          seedColor: Colors.green,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: .fromSeed(
          seedColor: Colors.green,
          dynamicSchemeVariant: DynamicSchemeVariant.neutral,
          brightness: Brightness.dark,
        ),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Note? _selectedNote;
  String _searchText = "";
  bool _isSearchEnabled = false;
  List<Note> _visibleNotes = [];
  final List<Note> _notes = [];
  final TextEditingController _noteContentController = TextEditingController();

  @override
  void initState() {
    Future<List<Note>> loadedNotes = loadSavedNotes();
    loadedNotes.then((value) {
      setState(() {
        _notes.addAll(value);
        _visibleNotes = _notes;
      });
    });
    super.initState();
  }

  void _updateNoteFiltering(String searchText) {
    setState(() {
      _searchText = searchText;
      _visibleNotes = _notes.where((note) {
        final noteTitle = extractTitle(note.content).toLowerCase();
        return noteTitle.contains(searchText.toLowerCase());
      }).toList();
    });
  }

  void _createNewNote() {
    setState(() {
      Note newNote = Note(
        uniqueId: generateTimestampRandomId(),
        date: DateTime.now(),
      );
      _notes.add(newNote);
      _visibleNotes = _notes;
      _selectedNote = newNote;
      _noteContentController.text = newNote.content;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchEnabled = !_isSearchEnabled;

      if (!_isSearchEnabled) {
        _visibleNotes = _notes;
      }
    });
  }

  void _toggleMenu() {
    final resultFut = showDialog<bool>(
      context: context,
      builder: (ctx) => SettingsMenu(),
    );

    resultFut.then((val) {
      print(val);
    });
  }

  void _selectNote(Note note) {
    setState(() {
      _selectedNote = note;
      _noteContentController.text = note.content;
    });
  }

  void _updateNoteContent(String newContent) {
    if (_selectedNote == null) {
      return;
    }

    setState(() {
      _selectedNote!.content = newContent;
    });

    autoSave.run(() {
      saveFile(_selectedNote!.uniqueId, newContent);
    });
  }

  void _deleteNote(Note note) {
    deleteNoteFile(note);

    setState(() {
      if (note == _selectedNote) {
        _selectedNote = null;
        _noteContentController.text = "";
      }

      _notes.remove(note);
      _visibleNotes = _notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              FakeNativeWindowBar(
                selectedNote: _selectedNote,
                isSearchEnabled: _isSearchEnabled,
                onSearchTextUpdated: _updateNoteFiltering,
                onToggleSearch: _toggleSearch,
                onToggleMenu: _toggleMenu,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SideBar(
                      notes: _visibleNotes,
                      onNoteSelected: _selectNote,
                      onNoteDeleted: _deleteNote,
                      currentlySelectedNote: _selectedNote,
                    ),
                    Expanded(
                      child: TextField(
                        textAlign: _selectedNote != null
                            ? TextAlign.start
                            : TextAlign.center,
                        textAlignVertical: _selectedNote != null
                            ? TextAlignVertical.top
                            : TextAlignVertical.center,
                        controller: _noteContentController,
                        onChanged: (value) => {_updateNoteContent(value)},
                        maxLines: null,
                        expands: true,
                        enabled: _selectedNote != null,
                        decoration: InputDecoration(
                          hintText: _selectedNote != null
                              ? "Your note here..."
                              : "Create a note to start",
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withAlpha(150),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Center(child: _isMenuOpen ? SettingsMenu() : Container()),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
    );
  }
}
