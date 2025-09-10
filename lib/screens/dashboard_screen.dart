import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/csv_service.dart';
import '../services/alert_service.dart';
import '../widgets/soil_health_card.dart';
import '../widgets/gauges.dart';
import '../widgets/nutrient_card.dart';
import 'graph_screen.dart';
import 'heatmap_screen.dart'; // ✅ New import

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String espIP = "192.168.4.1"; // ESP8266 IP

  // ✅ Sensor values
  double pH = 7.0;
  double temperature = 25.0;
  double humidity = 50.0;
  double ec = 0.0;
  int N = 0, P = 0, K = 0;

  // ✅ Historical readings
  List<double> pHReadings = [];
  List<double> temperatureReadings = [];
  List<double> humidityReadings = [];
  List<double> ecReadings = [];
  List<double> nReadings = [];
  List<double> pReadings = [];
  List<double> kReadings = [];
  List<DateTime> timestamps = [];

  Timer? _timer;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchSensorData();
    });
    _loadAssetCSV();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ✅ ESP fetch
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

          pHReadings.add(pH);
          temperatureReadings.add(temperature);
          humidityReadings.add(humidity);
          ecReadings.add(ec);
          nReadings.add(N.toDouble());
          pReadings.add(P.toDouble());
          kReadings.add(K.toDouble());
          timestamps.add(DateTime.now());

          // ✅ Keep last 50 samples
          if (timestamps.length > 50) {
            pHReadings.removeAt(0);
            temperatureReadings.removeAt(0);
            humidityReadings.removeAt(0);
            ecReadings.removeAt(0);
            nReadings.removeAt(0);
            pReadings.removeAt(0);
            kReadings.removeAt(0);
            timestamps.removeAt(0);
          }
        });
      }
    } catch (_) {}
  }

  // ✅ Load default asset CSV
  Future<void> _loadAssetCSV() async {
    final csvString = await rootBundle.loadString('assets/data_aug24.csv');
    final parsed = await CSVService.parseCSV(csvString);
    _applyCSV(parsed);
  }

  // ✅ Pick CSV
  Future<void> pickCsvFile() async {
    final parsed = await CSVService.pickCSV();
    if (parsed != null) {
      setState(() => _applyCSV(parsed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Loaded ${parsed["timestamps"]!.length} rows")),
      );
    }
  }

  // ✅ Apply parsed CSV
  void _applyCSV(Map<String, List<dynamic>> parsed) {
    pHReadings = parsed["pH"]!.cast<double>();
    temperatureReadings = parsed["temperature"]!.cast<double>();
    humidityReadings = parsed["humidity"]!.cast<double>();
    ecReadings = parsed["EC"]!.cast<double>();
    nReadings = parsed["N"]!.cast<double>();
    pReadings = parsed["P"]!.cast<double>();
    kReadings = parsed["K"]!.cast<double>();
    timestamps = parsed["timestamps"]!.cast<DateTime>();
  }

  String _formatTimestamp(int index) {
    if (index < 0 || index >= timestamps.length) return "";
    return DateFormat("MM-dd HH:mm").format(timestamps[index]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("🌱 Soil Sensor Dashboard"),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: "Load CSV",
              onPressed: pickCsvFile,
            ),
            IconButton(
              icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () => setState(() => isDarkMode = !isDarkMode),
            ),
            IconButton(
              icon: const Icon(Icons.show_chart),
              tooltip: "Open Graphs",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GraphScreen(
                      pHReadings: pHReadings,
                      nReadings: nReadings,
                      pReadings: pReadings,
                      kReadings: kReadings,
                      timestamps: timestamps,
                      temperatureReadings: temperatureReadings,
                      humidityReadings: humidityReadings,
                      ecReadings: ecReadings,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.grid_on),
              tooltip: "Open Heatmaps",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeatmapScreen(
                      pHReadings: pHReadings,
                      temperatureReadings: temperatureReadings,
                      humidityReadings: humidityReadings,
                      ecReadings: ecReadings,
                      nReadings: nReadings,
                      pReadings: pReadings,
                      kReadings: kReadings,
                      timestamps: timestamps,
                    ),
                  ),
                );
              },
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
              Text("🌡️ Temp: $temperature °C   💧 Humidity: $humidity%   ⚡ EC: $ec"),
            ],
          ),
        ),
      ),
    );
  }
}
