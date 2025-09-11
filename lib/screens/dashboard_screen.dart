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
  // Load default CSV asset safely
  Future<void> _loadAssetCSV() async {
    try {
      final csvString = await rootBundle.loadString('assets/simulated_soil_square.csv');

      final parsed = await CSVService.parseCSV(csvString);

      // Check if parsing returned valid data
      if (parsed == null ||
          parsed["timestamps"] == null ||
          parsed["pH"] == null ||
          parsed["temperature"] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load default CSV or CSV is empty")),
        );
        return;
      }

      _updateProvider(parsed);
  
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Loaded default CSV with ${parsed["timestamps"]!.length} rows successfully",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading default CSV: $e")),
      );
      print("Default CSV loading error: $e");
    }
  }
  
  // Pick CSV file
  // Pick CSV file safely
  Future<void> pickCsvFile() async {
    try {
      final parsed = await CSVService.pickCSV();

      // Check if parsing returned anything
      if (parsed == null ||
          parsed["timestamps"] == null ||
          parsed["pH"] == null ||
          parsed["temperature"] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load CSV or CSV is empty")),
        );
        return;
      }
  
      // Update provider safely
      _updateProvider(parsed);
  
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Loaded ${parsed["timestamps"]!.length} rows successfully")),
      );
    } catch (e) {
      // Catch any unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading CSV: $e")),
      );
      print("CSV loading error: $e");
    }
  }
  
  // Safe provider update
  void _updateProvider(Map<String, List<dynamic>> parsed) {
    final provider = context.read<CSVDataProvider>();

    // Make sure all required keys exist
    if (parsed["timestamps"] == null ||
        parsed["pH"] == null ||
        parsed["temperature"] == null ||
        parsed["humidity"] == null ||
        parsed["EC"] == null ||
        parsed["N"] == null ||
        parsed["P"] == null ||
        parsed["K"] == null ||
        parsed["latitudes"] == null ||
        parsed["longitudes"] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CSV missing required columns")),
      );
      return;
    }
    
    try {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating provider: $e")),
      );
      print("Provider update error: $e");
    }
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
