import 'package:flutter/material.dart';

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text('Settings'),
            // SizedBox(height: 24),
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      for (final color in [
                        Colors.red,
                        Colors.green,
                        Colors.blue,
                        Colors.yellow,
                        Colors.deepOrange,
                        Colors.indigoAccent,
                        Colors.pink,
                        Colors.purple,
                        Colors.teal,
                        Colors.lime,
                      ])
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(color),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          icon: Icon(Icons.check),
                        ),
                    ],
                  ),
                  SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.center,
                    spacing: 8.0,
                    overflowSpacing: 8.0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.auto_awesome),
                        tooltip: "System",
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.light_mode),
                        tooltip: "Light",
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.dark_mode),
                        tooltip: "Dark",
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
