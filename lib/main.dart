import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const SoilSensorApp());
}

class SoilSensorApp extends StatelessWidget {
  const SoilSensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "🌱 Soil Sensor Dashboard",
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const DashboardScreen(),
    );
  }
}
