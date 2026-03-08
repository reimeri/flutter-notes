import 'package:noteit/note.dart';
import 'package:noteit/utils/misc.dart';
import 'package:flutter/material.dart';

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
              : null,
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
