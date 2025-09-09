import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import '../services/csv_service.dart';
import '../widgets/soil_health_card.dart';
import '../widgets/gauges.dart';
import '../widgets/nutrient_card.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/multi_line_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double pH = 7.0;
  int N = 0, P = 0, K = 0;
  List<double> pHReadings = [], nReadings = [], pReadings = [], kReadings = [];
  List<DateTime> timestamps = [];

  Timer? _timer;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();

    // Fetch live sensor data every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      SensorService.fetchSensorData(onData: (data) {
        setState(() {
          pH = data.pH;
          N = data.N;
          P = data.P;
          K = data.K;
          pHReadings = data.pHReadings;
          nReadings = data.nReadings;
          pReadings = data.pReadings;
          kReadings = data.kReadings;
          timestamps = data.timestamps;
        });
      });
    });

    // Load CSV initially
    CsvService.loadDummyCSV().then((rows) {
      setState(() {
        CsvService.loadCsvRows(rows, this);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🌱 Soil Sensor Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Load CSV",
            onPressed: () => CsvService.pickCsvFile(context, this),
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
            Gauges(pH: pH),
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
                        LineChartWidget(data: pHReadings, timestamps: timestamps, label: "pH", color: Colors.green),
                        LineChartWidget(data: nReadings, timestamps: timestamps, label: "N", color: Colors.blue),
                        LineChartWidget(data: pReadings, timestamps: timestamps, label: "P", color: Colors.orange),
                        LineChartWidget(data: kReadings, timestamps: timestamps, label: "K", color: Colors.purple),
                        MultiLineChart(
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
    );
  }
}

