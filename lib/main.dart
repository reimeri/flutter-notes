import 'package:NoteIt/components/settings_menu.dart';
import 'package:NoteIt/components/side_bar.dart';
import 'package:NoteIt/components/fake_native_window_bar.dart';
import 'package:NoteIt/utils/markdown_controller.dart';
import 'package:flutter/material.dart';
import 'package:NoteIt/utils/auto_debounce.dart';
import 'package:NoteIt/utils/misc.dart';
import 'package:NoteIt/utils/file_utils.dart';
import 'package:NoteIt/note.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
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
  final MarkdownController _noteContentController = MarkdownController();

  // Key used to locate the TextField's RenderEditable for cursor tracking.
  final GlobalKey _textFieldKey = GlobalKey();
  final ScrollController _editorScrollController = ScrollController();

  @override
  void dispose() {
    _editorScrollController.dispose();
    super.dispose();
  }

  /// Walks the render subtree rooted at [root] to find the first
  /// [RenderEditable], which is the leaf renderer inside [TextField].
  RenderEditable? _findRenderEditable(RenderObject root) {
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  /// After any programmatic value change (Enter / Tab) the cursor position is
  /// updated by the controller but Flutter's normal show-caret pipeline is
  /// bypassed.  This method replays that pipeline: it finds the RenderEditable,
  /// computes the caret rect in local coordinates, and calls showOnScreen so
  /// the enclosing SingleChildScrollView scrolls to keep the cursor visible.
  void _ensureCursorVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _textFieldKey.currentContext;
      if (ctx == null) return;
      final root = ctx.findRenderObject();
      if (root == null) return;
      final editable = _findRenderEditable(root);
      if (editable == null) return;
      final position = _noteContentController.value.selection.extent;
      if (!_noteContentController.value.selection.isValid) return;
      final caretRect = editable.getLocalRectForCaret(position);
      // Inflate slightly so the line above/below the cursor is also visible.
      editable.showOnScreen(
        rect: caretRect.inflate(caretRect.height),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleEnterKey() {
    _noteContentController.handleEnterKey();
    _ensureCursorVisible();
  }

  void _handleTabKey() {
    _noteContentController.handleTabKey();
    _ensureCursorVisible();
  }

  void _handleShiftTabKey() {
    _noteContentController.handleTabKey(shift: true);
    _ensureCursorVisible();
  }

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
                      child: LayoutBuilder(
                        builder: (context, constraints) => Center(
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.enter):
                                  _handleEnterKey,
                              const SingleActivator(LogicalKeyboardKey.tab):
                                  _handleTabKey,
                              const SingleActivator(
                                LogicalKeyboardKey.tab,
                                shift: true,
                              ): _handleShiftTabKey,
                            },
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 700),
                              child: SingleChildScrollView(
                                controller: _editorScrollController,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: IntrinsicHeight(
                                    child: TextField(
                                      key: _textFieldKey,
                                      autofocus: true,
                                      textAlign: _selectedNote != null
                                          ? TextAlign.start
                                          : TextAlign.center,
                                      textAlignVertical: _selectedNote != null
                                          ? TextAlignVertical.top
                                          : TextAlignVertical.center,
                                      controller: _noteContentController,
                                      onChanged: (value) => {
                                        _updateNoteContent(value),
                                      },
                                      maxLines: null,
                                      expands: true,
                                      enabled: _selectedNote != null,
                                      decoration: InputDecoration(
                                        hintText: _selectedNote != null
                                            ? "Your note here..."
                                            : "Select a note to start",
                                        hintStyle: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withAlpha(150),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
