import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

// Import widgets
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 🔹 Fetch from ESP8266
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

  // 🔹 Pick CSV file
  Future<void> pickCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final rawData = await file.readAsString();

        List<List<dynamic>> rows =
            const CsvToListConverter().convert(rawData, eol: '\n');

        setState(() {
          _loadCsvRows(rows);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loaded ${rows.length - 1} rows from CSV")),
        );
      }
    } catch (e) {
      debugPrint("CSV pick error: $e");
    }
  }

  // 🔹 Helper: load CSV rows into state
  void _loadCsvRows(List<List<dynamic>> rows) {
    pHReadings.clear();
    nReadings.clear();
    pReadings.clear();
    kReadings.clear();
    timestamps.clear();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      try {
        timestamps.add(DateTime.parse(row[0]));
        pHReadings.add(row[1].toDouble());
        nReadings.add(row[2].toDouble());
        pReadings.add(row[3].toDouble());
        kReadings.add(row[4].toDouble());
      } catch (_) {}
    }
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
              SoilHealthCard(pH: pH),
              const SizedBox(height: 20),
              GaugesWidget(pH: pH),
              const SizedBox(height: 20),
              NutrientCard(N: N, P: P, K: K),
              const SizedBox(height: 20),

              // Graphs
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
