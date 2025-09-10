// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // ✅ global theme mode notifier
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.system);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Soil Dashboard',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode, // ✅ listen to notifier
          home: const DashboardScreen(),
        );
      },
    );
  }
}
