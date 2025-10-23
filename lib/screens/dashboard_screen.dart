// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
import 'robot_control_screen.dart'; // Import the new screen
import '../providers/csv_data_provider.dart';
import 'settings_screen.dart';

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
    try {
      final csvString = await rootBundle.loadString('assets/synthetic_soil_and_plant_data_s2_pattern.csv');
      final parsed = await CSVService.parseCSV(csvString);

      // Check if parsing returned valid data
      if (parsed == null) {
        _showSnackBar("Failed to parse default CSV (parsed = null)");
        return;
      }

      final missing = _checkMissingColumns(parsed);
      if (missing.isNotEmpty) {
        _showSnackBar("Default CSV missing columns: ${missing.join(", ")}");
        return;
      }

      _updateProvider(parsed);

      _showSnackBar(
        "Loaded default CSV with ${parsed["timestamps"]!.length} rows successfully",
      );
    } catch (e) {
      _showSnackBar("Error loading default CSV: $e");
      debugPrint("Default CSV loading error: $e");
    }
  }

  // Pick CSV file
  Future<void> pickCsvFile() async {
    try {
      final parsed = await CSVService.pickCSV();

      if (parsed == null) {
        _showSnackBar("Failed to parse picked CSV (parsed = null)");
        return;
      }

      final missing = _checkMissingColumns(parsed);
      if (missing.isNotEmpty) {
        _showSnackBar("Picked CSV missing columns: ${missing.join(", ")}");
        return;
      }

      _updateProvider(parsed);

      _showSnackBar("Loaded ${parsed["timestamps"]!.length} rows successfully");
    } catch (e) {
      _showSnackBar("Error loading CSV: $e");
      debugPrint("CSV loading error: $e");
    }
  }

  // Helper: normalize keys to lowercase
  Map<String, List<dynamic>> _normalizeKeys(Map<String, List<dynamic>> parsed) {
    final normalized = <String, List<dynamic>>{};
    for (var entry in parsed.entries) {
      normalized[entry.key.toLowerCase()] = entry.value;
    }
    return normalized;
  }

  // Safe provider update
  void _updateProvider(Map<String, List<dynamic>> parsed) {
    try {
      final provider = context.read<CSVDataProvider>();
      final normalized = _normalizeKeys(parsed);

      provider.updateData(
        pH: normalized["ph"]!.cast<double>(),
        temperature: normalized["temperature"]!.cast<double>(),
        humidity: normalized["humidity"]!.cast<double>(),
        ec: normalized["ec"]!.cast<double>(),
        n: normalized["n"]!.cast<double>(),
        p: normalized["p"]!.cast<double>(),
        k: normalized["k"]!.cast<double>(),
        timestamps: normalized["timestamps"]!.cast<DateTime>(),
        latitudes: normalized["latitudes"]!.cast<double>(),
        longitudes: normalized["longitudes"]!.cast<double>(),
        plantStatus: (normalized["plant_status"] ?? const <dynamic>[]) 
            .map((e) => e?.toString() ?? '')
            .toList(),
      );

      _showSnackBar("✅ CSV data loaded successfully!");
    } catch (e) {
      _showSnackBar("❌ Error updating provider:\n$e");
    }
  }

  // Helper: check missing columns with debug
  List<String> _checkMissingColumns(Map<String, List<dynamic>> parsed) {
    final normalized = _normalizeKeys(parsed);

    final requiredCols = [
      "timestamps",
      "ph",
      "temperature",
      "humidity",
      "ec",
      "n",
      "p",
      "k",
      "latitudes",
      "longitudes",
    ];

    final missing = <String>[];
    for (var col in requiredCols) {
      if (!normalized.containsKey(col) || normalized[col] == null || normalized[col]!.isEmpty) {
        missing.add(col);
      }
    }

    // Also grab the available keys for debugging
    final available = normalized.keys.toList();

    if (missing.isNotEmpty) {
      _showSnackBar(
        "⚠️ Missing CSV columns: ${missing.join(", ")}\n"
        "📄 Found columns: ${available.join(", ")}",
      );
    } else {
      _showSnackBar(
        "✅ All required CSV columns found!\n"
        "📄 Found columns: ${available.join(", ")}",
      );
    }

    return missing;
  }

  // Helper: show snackbar
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
              // New button for the robot control screen
              IconButton(
                icon: const Icon(Icons.smart_toy),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RobotControlScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                NutrientCard(
                  N: N,
                  P: P,
                  K: K,
                  plantStatus: (() {
                    final provider = context.read<CSVDataProvider>();
                    if (provider.plantStatus.isNotEmpty) {
                      return provider.plantStatus.last;
                    }
                    return '';
                  })(),
                ),
                const SizedBox(height: 20),
                Text(
                  "🌡️ Temp: $temperature °C    💧 Humidity: $humidity%    ⚡ EC: $ec",
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
