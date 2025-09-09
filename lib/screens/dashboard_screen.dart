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
import '../widgets/line_chart.dart';
import '../widgets/multi_line_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String espIP = "192.168.4.1"; // ESP8266 IP

  double pH = 7.0;
  int N = 0, P = 0, K = 0;

  List<double> pHReadings = [];
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

  // ESP fetch
  Future<void> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse("http://$espIP/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          pH = data["pH"].toDouble();
          N = data["N"];
          P = data["P"];
          K = data["K"];

          pHReadings.add(pH);
          nReadings.add(N.toDouble());
          pReadings.add(P.toDouble());
          kReadings.add(K.toDouble());
          timestamps.add(DateTime.now());

          if (pHReadings.length > 50) {
            pHReadings.removeAt(0);
            nReadings.removeAt(0);
            pReadings.removeAt(0);
            kReadings.removeAt(0);
            timestamps.removeAt(0);
          }
        });
      }
    } catch (_) {}
  }

  // Load default asset CSV
  Future<void> _loadAssetCSV() async {
    final csvString = await rootBundle.loadString('assets/data_aug24.csv');
    final parsed = await CSVService.parseCSV(csvString);
    _applyCSV(parsed);
  }

  // Pick CSV from device
  Future<void> pickCsvFile() async {
    final parsed = await CSVService.pickCSV();
    if (parsed != null) {
      setState(() => _applyCSV(parsed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Loaded ${parsed["timestamps"]!.length} rows")),
      );
    }
  }

  void _applyCSV(Map<String, List<dynamic>> parsed) {
    pHReadings = parsed["pH"]!.cast<double>();
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
              DefaultTabController(
                length: 5,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.green,
                      unselectedLabelColor: Colors.grey,
                      isScrollable: true,
                      tabs: [
                        Tab(text: "pH"),
                        Tab(text: "N"),
                        Tab(text: "P"),
                        Tab(text: "K"),
                        Tab(text: "All"),
                      ],
                    ),
                    SizedBox(
                      height: 350,
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(), //Yeah stop the annoying scroll
                        children: [
                          LineChartWidget(data: pHReadings, color: Colors.green, label: "pH", timestamps: timestamps),
                          LineChartWidget(data: nReadings, color: Colors.blue, label: "N", timestamps: timestamps),
                          LineChartWidget(data: pReadings, color: Colors.orange, label: "P", timestamps: timestamps),
                          LineChartWidget(data: kReadings, color: Colors.purple, label: "K", timestamps: timestamps),
                          MultiLineChartWidget(
                            pHData: pHReadings,
                            nData: nReadings,
                            pData: pReadings,
                            kData: kReadings,
                            timestamps: timestamps,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
