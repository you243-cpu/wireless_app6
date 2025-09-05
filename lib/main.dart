import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // For gauges

void main() {
  runApp(const SoilSensorApp());
}

class SoilSensorApp extends StatefulWidget {
  const SoilSensorApp({super.key});

  @override
  State<SoilSensorApp> createState() => _SoilSensorAppState();
}

class _SoilSensorAppState extends State<SoilSensorApp> {
  final String espIP = "192.168.4.1"; // ESP8266 IP

  double pH = 7.0;
  int N = 0, P = 0, K = 0;

  List<double> pHReadings = [];

  Timer? _timer;
  bool isDarkMode = false; // For theme switching

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

          if (pHReadings.length > 20) pHReadings.removeAt(0);
        });
      }
    } catch (e) {
      print("Fetch error: $e");
    }
  }

  // Alert messages
  String getAlertMessage() {
    if (pH < 5.5) return "⚠️ Soil too acidic. Add lime.";
    if (pH > 7.5) return "⚠️ Soil too alkaline. Add sulfur.";
    return "✅ Soil conditions look healthy!";
  }

  Color getpHColor() {
    if (pH < 5.5 || pH > 7.5) return Colors.red;
    return Colors.green;
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
              icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () => setState(() => isDarkMode = !isDarkMode),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Dashboard summary card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text("Overall Soil Health",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black)),
                      const SizedBox(height: 10),
                      Text(getAlertMessage(),
                          style: TextStyle(fontSize: 16, color: getpHColor())),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Gauges Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularPercentIndicator(
                    radius: 60,
                    lineWidth: 12,
                    percent: (pH / 14).clamp(0.0, 1.0),
                    center: Text(pH.toStringAsFixed(2)),
                    progressColor: getpHColor(),
                    footer: const Text("pH"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Nutrient cards
              Card(
                elevation: 3,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.science, color: Colors.blue),
                      title: const Text("Nitrogen (N)"),
                      trailing: Text("$N mg/kg"),
                    ),
                    ListTile(
                      leading: const Icon(Icons.science, color: Colors.orange),
                      title: const Text("Phosphorus (P)"),
                      trailing: Text("$P mg/kg"),
                    ),
                    ListTile(
                      leading: const Icon(Icons.science, color: Colors.purple),
                      title: const Text("Potassium (K)"),
                      trailing: Text("$K mg/kg"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Graphs with Tabs
              DefaultTabController(
                length: 1,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.green,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(icon: Icon(Icons.bubble_chart), text: "pH"),
                      ],
                    ),
                    SizedBox(
                      height: 250,
                      child: TabBarView(
                        children: [
                          _buildLineChart(pHReadings, 0, 14, Colors.green),
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

  // Chart builder function
  Widget _buildLineChart(List<double> data, double minY, double maxY, Color color) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
            show: true, border: Border.all(color: Colors.grey, width: 1)),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }
}