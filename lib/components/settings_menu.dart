import 'package:NoteIt/main.dart';
import 'package:flutter/material.dart';

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({
    super.key,
    required this.selectedColorTheme,
    required this.selectedThemeMode,
  });

  final Color selectedColorTheme;
  final ThemeMode selectedThemeMode;

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
                      for (final color in colorThemes)
                        IconButton(
                          onPressed: () => Navigator.pop(context, {
                            "colorTheme": color,
                            "themeMode": selectedThemeMode,
                          }),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(color),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          icon:
                              selectedColorTheme.toARGB32() == color.toARGB32()
                              ? Icon(Icons.check)
                              : Icon(null),
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
                        onPressed: () => Navigator.pop(context, {
                          "colorTheme": selectedColorTheme,
                          "themeMode": ThemeMode.system,
                        }),
                        icon: Icon(Icons.auto_awesome),
                        tooltip: "System",
                        style: selectedThemeMode == ThemeMode.system
                            ? ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                              )
                            : null,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, {
                          "colorTheme": selectedColorTheme,
                          "themeMode": ThemeMode.light,
                        }),
                        icon: Icon(Icons.light_mode),
                        tooltip: "Light",
                        style: selectedThemeMode == ThemeMode.light
                            ? ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                              )
                            : null,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, {
                          "colorTheme": selectedColorTheme,
                          "themeMode": ThemeMode.dark,
                        }),
                        icon: Icon(Icons.dark_mode),
                        tooltip: "Dark",
                        style: selectedThemeMode == ThemeMode.dark
                            ? ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                              )
                            : null,
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
