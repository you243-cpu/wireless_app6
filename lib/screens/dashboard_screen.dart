// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../services/csv_service.dart';
import 'package:wireless_appf/widgets/line_chart_card.dart';
import 'package:wireless_appf/widgets/multi_line_chart.dart';
import 'package:wireless_appf/widgets/soil_health_card.dart';
import 'package:wireless_appf/widgets/gauges.dart';
import 'package:wireless_appf/widgets/nutrient_card.dart';


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
    loadDummyCSV(); // initial dummy data from assets
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  Future<void> loadDummyCSV() async {
    try {
      final rows = await CsvService.loadFromAssets('assets/data_aug24.csv');
      final parsed = CsvService.parseRows(rows);
      setState(() {
        timestamps = parsed["timestamps"]!.cast<DateTime>();
        pHReadings = parsed["pH"]!.cast<double>();
        nReadings = parsed["N"]!.cast<double>();
        pReadings = parsed["P"]!.cast<double>();
        kReadings = parsed["K"]!.cast<double>();
      });
    } catch (e) {
      debugPrint("CSV load error: $e");
    }
  }

  Future<void> pickCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final rows = await CsvService.loadFromFile(file);
        final parsed = CsvService.parseRows(rows);

        setState(() {
          timestamps = parsed["timestamps"]!.cast<DateTime>();
          pHReadings = parsed["pH"]!.cast<double>();
          nReadings = parsed["N"]!.cast<double>();
          pReadings = parsed["P"]!.cast<double>();
          kReadings = parsed["K"]!.cast<double>();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loaded ${rows.length - 1} rows from CSV")),
        );
      }
    } catch (e) {
      debugPrint("CSV pick error: $e");
    }
  }

  String getAlertMessage() {
    if (pH < 5.5) return "⚠️ Soil too acidic. Add lime.";
    if (pH > 7.5) return "⚠️ Soil too alkaline. Add sulfur.";
    return "✅ Soil conditions look healthy!";
  }

  Color getpHColor() {
    if (pH < 5.5 || pH > 7.5) return Colors.red;
    return Colors.green;
  }

  String _formatTimestamp(int index) {
    if (index < 0 || index >= timestamps.length) return "";
    final dt = timestamps[index];
    return DateFormat("MM-dd HH:mm").format(dt);
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text("Overall Soil Health",
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Text(getAlertMessage(),
                          style: TextStyle(fontSize: 16, color: getpHColor())),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Charts
              DefaultTabController(
                length: 5,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.green,
                      unselectedLabelColor: Colors.grey,
                      isScrollable: true,
                      tabs: [
                        Tab(icon: Icon(Icons.bubble_chart), text: "pH"),
                        Tab(icon: Icon(Icons.science), text: "N"),
                        Tab(icon: Icon(Icons.science), text: "P"),
                        Tab(icon: Icon(Icons.science), text: "K"),
                        Tab(icon: Icon(Icons.dashboard), text: "All"),
                      ],
                    ),
                    SizedBox(
                      height: 350,
                      child: TabBarView(
                        children: [
                          LineChartWidget(
                            data: pHReadings,
                            timestamps: timestamps,
                            label: "pH",
                            color: Colors.green,
                          ),
                          LineChartWidget(
                            data: nReadings,
                            timestamps: timestamps,
                            label: "Nitrogen",
                            color: Colors.blue,
                          ),
                          LineChartWidget(
                            data: pReadings,
                            timestamps: timestamps,
                            label: "Phosphorus",
                            color: Colors.orange,
                          ),
                          LineChartWidget(
                            data: kReadings,
                            timestamps: timestamps,
                            label: "Potassium",
                            color: Colors.purple,
                          ),
                          MultiLineChartWidget(
                            pHReadings: pHReadings,
                            nReadings: nReadings,
                            pReadings: pReadings,
                            kReadings: kReadings,
                            timestamps: timestamps,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
