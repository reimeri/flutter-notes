import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/auto_debounce.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  final List<Note> _notes = [];
  final TextEditingController _noteContentController = TextEditingController();

  @override
  void initState() {
    Future<List<Note>> loadedNotes = loadSavedNotes();
    loadedNotes.then((value) {
      setState(() {
        _notes.addAll(value);
      });
    });
    super.initState();
  }

  void _createNewNote() {
    setState(() {
      Note newNote = Note(
        uniqueId: generateTimestampRandomId(),
        date: DateTime.now(),
      );
      _notes.add(newNote);
      _selectedNote = newNote;
      _noteContentController.text = newNote.content;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FakeNativeWindowBar(selectedNote: _selectedNote),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SideBar(
                  notes: _notes,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        tooltip: 'New note',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Note {
  Note({required this.uniqueId, required this.date, this.content = ""});

  final String uniqueId;
  final DateTime date;
  String content;
}

class SideBar extends StatelessWidget {
  const SideBar({
    super.key,
    required this.notes,
    required this.onNoteSelected,
    required this.currentlySelectedNote,
    required this.onNoteDeleted,
  });

  final void Function(Note) onNoteSelected;
  final void Function(Note) onNoteDeleted;
  final Note? currentlySelectedNote;
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) => Card(
          color: currentlySelectedNote == notes[(notes.length - 1) - index]
              ? Theme.of(context).colorScheme.inversePrimary
              : Theme.of(context).colorScheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: Padding(
              padding: EdgeInsetsGeometry.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      spacing: 10,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extractTitle(
                            notes[(notes.length - 1) - index].content,
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          beautifulDurationFromDate(
                            notes[(notes.length - 1) - index].date,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        onNoteDeleted(notes[(notes.length - 1) - index]),
                    icon: Icon(Icons.delete),
                  ),
                ],
              ),
            ),
            onTap: () => onNoteSelected(notes[(notes.length - 1) - index]),
          ),
        ),
      ),
    );
  }
}

class FakeNativeWindowBar extends StatelessWidget {
  const FakeNativeWindowBar({super.key, required this.selectedNote});

  final Note? selectedNote;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background with text for sidepanel top and editor top
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Container(
                alignment: AlignmentGeometry.center,
                width: 300,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Text(
                  style: TextStyle(fontWeight: FontWeight(750)),
                  "Notes",
                ),
              ),
              Expanded(
                child: Container(
                  alignment: AlignmentGeometry.center,
                  child: Text(
                    style: TextStyle(fontWeight: FontWeight(750)),
                    extractTitle(selectedNote?.content ?? ""),
                  ),
                ),
              ),
            ],
          ),
        ),
        DragToMoveArea(child: SizedBox(width: double.infinity, height: 40)),

        // Button layer. On top of the DragToMoveArea to avoid tap delay
        SizedBox(
          height: 40,
          child: Row(
            children: [
              // Side panel portion
              Container(
                padding: EdgeInsetsGeometry.all(4),
                width: 300,
                height: 40,
                alignment: AlignmentGeometry.centerStart,
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        icon: Icon(Icons.search),
                        onPressed: () async {
                          print("Search");
                        },
                      ),
                    ),
                    Expanded(child: Container()),
                    Expanded(child: Container()),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        icon: Icon(Icons.menu_rounded),
                        onPressed: () async {
                          print("Open menu");
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Note panel portion
              Expanded(
                child: Container(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
                  child: Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            style: Theme.of(context).iconButtonTheme.style,
                            icon: Icon(Icons.close),
                            onPressed: () async {
                              await windowManager.close();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String extractTitle(String content) {
  List<String> parts = content.split("\n");
  if (parts.isNotEmpty) {
    return parts[0];
  }

  return "";
}

String beautifulDurationFromDate(DateTime date) {
  Duration diff = DateTime.now().difference(date);

  if (diff.inDays > 0 && diff.inDays < 2) {
    return "Yesterday";
  }
  if (diff.inDays > 1) {
    return "${diff.inDays} days ago";
  }
  if (diff.inHours > 0 && diff.inHours < 2) {
    return "${diff.inHours} hour ago";
  }
  if (diff.inHours > 1) {
    return "${diff.inHours} hours ago";
  }
  if (diff.inMinutes > 0 && diff.inMinutes < 2) {
    return "${diff.inMinutes} minute ago";
  }
  if (diff.inMinutes > 1) {
    return "${diff.inMinutes} minutes ago";
  }

  return "Just now";
}

Future<void> saveFile(String fileName, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final notesFolder = Directory('${dir.path}/notes');
  await notesFolder.create();
  final file = File('${notesFolder.path}/$fileName.md');
  await file.writeAsString(content);
}

Future<List<File>> loadFiles() async {
  final List<File> files = [];
  final dir = await getApplicationDocumentsDirectory();
  final notesFolder = Directory('${dir.path}/notes');
  final fileList = notesFolder.listSync();
  for (final file in fileList) {
    files.add(File(file.path));
  }

  return files;
}

Future<List<Note>> loadSavedNotes() async {
  final List<Note> loadedNotes = [];

  final files = await loadFiles();
  for (final file in files) {
    if (!file.path.endsWith(".md")) {
      continue;
    }

    String fileName = p.basenameWithoutExtension(file.path);
    String content = file.readAsStringSync();
    DateTime date = DateTime.fromMicrosecondsSinceEpoch(
      int.parse(fileName.split("-")[0]),
    );
    Note loadedNote = Note(uniqueId: fileName, date: date, content: content);
    loadedNotes.add(loadedNote);
  }

  // Sort notes based on date
  loadedNotes.sort((a, b) {
    if (a.date.microsecondsSinceEpoch < b.date.microsecondsSinceEpoch) {
      return -1;
    } else if (a.date.microsecondsSinceEpoch > b.date.microsecondsSinceEpoch) {
      return 1;
    } else {
      return 0;
    }
  });

  return loadedNotes;
}

Future<String> readFile(String path) async {
  final file = File(path);
  return await file.readAsString();
}

void deleteNoteFile(Note note) async {
  final documentsDir = await getApplicationDocumentsDirectory();
  File file = File("${documentsDir.path}/notes/${note.uniqueId}.md");
  file.deleteSync();
  print("${note.uniqueId} deleted");
}

String generateTimestampRandomId() {
  return '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(100000)}';
}
