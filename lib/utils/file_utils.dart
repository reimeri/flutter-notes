import 'dart:io';

import 'package:NoteIt/note.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
