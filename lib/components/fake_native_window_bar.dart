import 'package:NoteIt/note.dart';
import 'package:NoteIt/utils/misc.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class FakeNativeWindowBar extends StatelessWidget {
  const FakeNativeWindowBar({
    super.key,
    required this.selectedNote,
    required this.isSearchEnabled,
    required this.onToggleSearch,
    required this.onToggleMenu,
    required this.onSearchTextUpdated,
  });

  final Note? selectedNote;
  final bool isSearchEnabled;
  final void Function() onToggleSearch;
  final void Function() onToggleMenu;
  final void Function(String) onSearchTextUpdated;

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
                child: Visibility(
                  visible: !isSearchEnabled,
                  child: Text(
                    style: TextStyle(fontWeight: FontWeight(750)),
                    "Notes",
                  ),
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
                          backgroundColor: isSearchEnabled
                              ? Theme.of(context).colorScheme.inversePrimary
                              : null,
                        ),
                        icon: Icon(Icons.search),
                        onPressed: onToggleSearch,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
                        child: isSearchEnabled
                            ? TextField(
                                style: TextStyle(fontSize: 20),
                                decoration: InputDecoration(
                                  hintText: "Search...",
                                ),
                                onChanged: (value) => {
                                  onSearchTextUpdated(value),
                                },
                              )
                            : Container(),
                      ),
                    ),
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
                        onPressed: onToggleMenu,
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
