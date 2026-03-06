class Note {
  Note({required this.uniqueId, required this.date, this.content = ""});

  final String uniqueId;
  final DateTime date;
  String content;
}
