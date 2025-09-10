// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/csv_service.dart';
import '../services/alert_service.dart';
import '../widgets/soil_health_card.dart';
import '../widgets/gauges.dart';
import '../widgets/nutrient_card.dart';
import 'graph_screen.dart';
import 'heatmap_screen.dart';
import '../providers/csv_data_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String espIP = "192.168.4.1"; // ESP8266 IP

  // Current sensor values
  double pH = 7.0;
  double temperature = 25.0;
  double humidity = 50.0;
  double ec = 0.0;
  int N = 0, P = 0, K = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchSensorData());
    _loadAssetCSV();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Fetch live sensor values from ESP
  Future<void> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse("http://$espIP/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          pH = (data["pH"] ?? pH).toDouble();
          temperature = (data["temperature"] ?? temperature).toDouble();
          humidity = (data["humidity"] ?? humidity).toDouble();
          ec = (data["EC"] ?? ec).toDouble();
          N = data["N"] ?? N;
          P = data["P"] ?? P;
          K = data["K"] ?? K;
        });

        // Also append to provider for history
        final provider = context.read<CSVDataProvider>();
        if (provider.hasData) {
          provider.pH.add(pH);
          provider.temperature.add(temperature);
          provider.humidity.add(humidity);
          provider.ec.add(ec);
          provider.n.add(N.toDouble());
          provider.p.add(P.toDouble());
          provider.k.add(K.toDouble());
          provider.timestamps.add(DateTime.now());

          // Keep last 50 samples
          if (provider.timestamps.length > 50) {
            provider.pH.removeAt(0);
            provider.temperature.removeAt(0);
            provider.humidity.removeAt(0);
            provider.ec.removeAt(0);
            provider.n.removeAt(0);
            provider.p.removeAt(0);
            provider.k.removeAt(0);
            provider.timestamps.removeAt(0);
          }
          provider.notifyListeners();
        }
      }
    } catch (_) {}
  }

  // Load default CSV asset
  Future<void> _loadAssetCSV() async {
    try{
      final csvString = await rootBundle.loadString('assets/simulated_soil_square.csv');
      final parsed = await CSVService.parseCSV(csvString);
      _updateProvider(parsed);

    // Prepare preview for SnackBar
    final numPreview = 3; // first 3 rows
    final totalRows = parsed["timestamps"]!.length;
    final previewRows = <String>[];

    for (int i = 0; i < totalRows && i < numPreview; i++) {
      previewRows.add(
        "Row ${i + 1}: pH=${parsed["pH"]![i]}, Temp=${parsed["temperature"]![i]}, Humidity=${parsed["humidity"]![i]}"
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Default CSV loaded: $totalRows rows.\n" + previewRows.join("\n"),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load default CSV: $e"),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  // Pick CSV file
  Future<void> pickCsvFile() async {
    final parsed = await CSVService.pickCSV();
    if (parsed != null) {
      _updateProvider(parsed);

      //Prepare preview for Snax
      final numPreview = 3;
      final totalRows = parsed["timestamps"]!.length;
      final previewRows = <String>[];

      for (int i = 0; i < totalRows && i < numPreview; i++) {
        previewRows.add(
          "Row ${i + 1}: pH=${parsed["pH"]![i]}, Temp=${parsed["temperature"]![i]}. Humidity=${parsed["humidity"]![i]}"
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Loaded $totalRows rows. \n + previewRows.join("\n"),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No CSV selected or failed to load."),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _updateProvider(Map<String, List<dynamic>> parsed) {
    final provider = context.read<CSVDataProvider>();
    provider.updateData(
      pH: parsed["pH"]!.cast<double>(),
      temperature: parsed["temperature"]!.cast<double>(),
      humidity: parsed["humidity"]!.cast<double>(),
      ec: parsed["EC"]!.cast<double>(),
      n: parsed["N"]!.cast<double>(),
      p: parsed["P"]!.cast<double>(),
      k: parsed["K"]!.cast<double>(),
      timestamps: parsed["timestamps"]!.cast<DateTime>(),
      latitudes: parsed["latitudes"]!.cast<double>(),
      longitudes: parsed["longitudes"]!.cast<double>(),
    );
  }

  void _toggleTheme() {
    final current = MyApp.themeNotifier.value;
    MyApp.themeNotifier.value = current == ThemeMode.system
        ? ThemeMode.light
        : current == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.system;
  }

  Icon _themeIcon() {
    final mode = MyApp.themeNotifier.value;
    if (mode == ThemeMode.dark) return const Icon(Icons.dark_mode);
    if (mode == ThemeMode.light) return const Icon(Icons.light_mode);
    return const Icon(Icons.brightness_auto);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CSVDataProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("🌱 Soil Sensor Dashboard"),
            actions: [
              IconButton(icon: const Icon(Icons.upload_file), onPressed: pickCsvFile),
              IconButton(icon: _themeIcon(), onPressed: _toggleTheme),
              IconButton(
                icon: const Icon(Icons.show_chart),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GraphScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.grid_on),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HeatmapScreen()),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SoilHealthCard(message: AlertService.getAlertMessage(pH)),
                const SizedBox(height: 20),
                GaugesWidget(pH: pH),
                const SizedBox(height: 20),
                NutrientCard(N: N, P: P, K: K),
                const SizedBox(height: 20),
                Text(
                  "🌡️ Temp: $temperature °C   💧 Humidity: $humidity%   ⚡ EC: $ec",
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
