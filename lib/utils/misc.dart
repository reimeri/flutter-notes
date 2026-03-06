import 'dart:math';

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

String generateTimestampRandomId() {
  return '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(100000)}';
}
