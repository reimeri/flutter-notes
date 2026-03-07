import 'package:NoteIt/components/settings_menu.dart';
import 'package:NoteIt/components/side_bar.dart';
import 'package:NoteIt/components/fake_native_window_bar.dart';
import 'package:flutter/material.dart';
import 'package:NoteIt/utils/auto_debounce.dart';
import 'package:NoteIt/utils/misc.dart';
import 'package:NoteIt/utils/file_utils.dart';
import 'package:NoteIt/note.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

final autoSave = AutoDebouncer();

final colorThemes = [
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.white,
  Colors.orange,
  Colors.indigoAccent,
  Colors.pink,
  Colors.purple,
  Colors.teal,
  Colors.lime,
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final themeModeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
  final colorThemeValue =
      prefs.getInt('colorTheme') ?? colorThemes[0].toARGB32();

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

  runApp(
    MyApp(
      themeMode: ThemeMode.values[themeModeIndex],
      selectedColorTheme: Color(colorThemeValue),
    ),
  );
}

class MyApp extends StatefulWidget {
  MyApp({super.key, required this.selectedColorTheme, required this.themeMode});

  Color selectedColorTheme;
  ThemeMode themeMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void changeTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    setState(() => widget.themeMode = mode);
  }

  void changeColorTheme(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colorTheme', color.toARGB32());
    setState(() => widget.selectedColorTheme = color);
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteIt',
      themeMode: widget.themeMode,
      theme: ThemeData(
        colorScheme: .fromSeed(
          seedColor: widget.selectedColorTheme,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: .fromSeed(
          seedColor: widget.selectedColorTheme,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
          brightness: Brightness.dark,
        ),
      ),
      home: MyHomePage(
        selectedColorTheme: widget.selectedColorTheme,
        selectedThemeMode: widget.themeMode,
        onColorThemeChange: changeColorTheme,
        onThemeModeChange: changeTheme,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({
    super.key,
    required this.selectedColorTheme,
    required this.selectedThemeMode,
    required this.onColorThemeChange,
    required this.onThemeModeChange,
  });

  Color selectedColorTheme;
  ThemeMode selectedThemeMode;
  void Function(Color color) onColorThemeChange;
  void Function(ThemeMode mode) onThemeModeChange;

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
    super.initState();
    Future<List<Note>> loadedNotes = loadSavedNotes();
    loadedNotes.then((value) {
      setState(() {
        _notes.addAll(value);
        _visibleNotes = _notes;
      });
    });
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
    final resultFut = showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SettingsMenu(
        selectedThemeMode: widget.selectedThemeMode,
        selectedColorTheme: widget.selectedColorTheme,
      ),
    );

    resultFut.then((val) {
      print(val);

      if (val == null) {
        return;
      }

      setState(() {
        widget.onColorThemeChange(val["colorTheme"]);
        widget.onThemeModeChange(val["themeMode"]);
      });
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
                              : "Select a note to start",
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
