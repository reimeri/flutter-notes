import 'package:NoteIt/note.dart';
import 'package:NoteIt/utils/misc.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class FakeNativeWindowBar extends StatefulWidget {
  const FakeNativeWindowBar({super.key, required this.selectedNote});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final Note? selectedNote;

  @override
  State<FakeNativeWindowBar> createState() => _FakeNativeWindowBarState();
}

class _FakeNativeWindowBarState extends State<FakeNativeWindowBar> {
  bool _isSearchOpen = false;

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
    });
  }

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
                  visible: !_isSearchOpen,
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
                    extractTitle(widget.selectedNote?.content ?? ""),
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
                          backgroundColor: _isSearchOpen
                              ? Theme.of(context).colorScheme.inversePrimary
                              : null,
                        ),
                        icon: Icon(Icons.search),
                        onPressed: _toggleSearch,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
                        child: _isSearchOpen
                            ? TextField(
                                style: TextStyle(fontSize: 20),
                                decoration: InputDecoration(
                                  hintText: "Search...",
                                  fillColor: Colors.amber,
                                  hoverColor: Colors.amber,
                                ),
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
