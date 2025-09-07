import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

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
  List<double> nReadings = [];
  List<double> pReadings = [];
  List<double> kReadings = [];
  List<DateTime> timestamps = [];

  Timer? _timer;
  bool isDarkMode = false;

  final TransformationController _zoomController = TransformationController();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchSensorData();
    });
    loadDummyCSV();
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
      print("Fetch error: $e");
    }
  }

  Future<void> loadDummyCSV() async {
    try {
      final csvString = await rootBundle.loadString('assets/data_aug24.csv');
      final rows = const CsvToListConverter().convert(csvString, eol: "\n");

      setState(() {
        pHReadings.clear();
        nReadings.clear();
        pReadings.clear();
        kReadings.clear();
        timestamps.clear();

        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          timestamps.add(DateTime.parse(row[0]));
          pHReadings.add(row[1].toDouble());
          nReadings.add(row[2].toDouble());
          pReadings.add(row[3].toDouble());
          kReadings.add(row[4].toDouble());
        }
      });
    } catch (e) {
      print("CSV load error: $e");
    }
  }

  // Alerts
  String getAlertMessage() {
    if (pH < 5.5) return "⚠️ Soil too acidic. Add lime.";
    if (pH > 7.5) return "⚠️ Soil too alkaline. Add sulfur.";
    return "✅ Soil conditions look healthy!";
  }

  Color getpHColor() {
    if (pH < 5.5 || pH > 7.5) return Colors.red;
    return Colors.green;
  }

  void resetZoom() {
    setState(() {
      _zoomController.value = Matrix4.identity();
    });
  }

  double _getMinY(List<double> data) {
    if (data.isEmpty) return 0;
    final minVal = data.reduce((a, b) => a < b ? a : b);
    return (minVal - 5).clamp(0, double.infinity);
  }

  double _getMaxY(List<double> data) {
    if (data.isEmpty) return 10;
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    return maxVal + 5;
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
              icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () => setState(() => isDarkMode = !isDarkMode),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Reset Zoom",
              onPressed: resetZoom,
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

              // Gauges
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

              // Nutrients
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
                          _buildLineChart(pHReadings, Colors.green, "pH"),
                          _buildLineChart(nReadings, Colors.blue, "Nitrogen"),
                          _buildLineChart(pReadings, Colors.orange, "Phosphorus"),
                          _buildLineChart(kReadings, Colors.purple, "Potassium"),
                          _buildMultiLineChart(),
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

  // Single line chart with timestamps
  Widget _buildLineChart(List<double> data, Color color, String label) {
    return InteractiveViewer(
      transformationController: _zoomController,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 3.0,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.length / 4).clamp(1, 10).toDouble(),
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index % 5 == 0 && index < timestamps.length) {
                    return Text(_formatTimestamp(index),
                        style: const TextStyle(fontSize: 10));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(
              show: true, border: Border.all(color: Colors.grey, width: 1)),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: _getMinY(data),
          maxY: _getMaxY(data),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                  .toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData:
                  BarAreaData(show: true, color: color.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  // Multi-line chart with legend
  Widget _buildMultiLineChart() {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            transformationController: _zoomController,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 3.0,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (pHReadings.length / 4).clamp(1, 10).toDouble(),
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index % 5 == 0 && index < timestamps.length) {
                          return Text(_formatTimestamp(index),
                              style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                    show: true, border: Border.all(color: Colors.grey, width: 1)),
                minX: 0,
                maxX: (pHReadings.length - 1).toDouble(),
                minY: _getMinY([...pHReadings, ...nReadings, ...pReadings, ...kReadings]),
                maxY: _getMaxY([...pHReadings, ...nReadings, ...pReadings, ...kReadings]),
                lineBarsData: [
                  _makeLine(pHReadings, Colors.green),
                  _makeLine(nReadings, Colors.blue),
                  _makeLine(pReadings, Colors.orange),
                  _makeLine(kReadings, Colors.purple),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          children: [
            _buildLegendItem(Colors.green, "pH"),
            _buildLegendItem(Colors.blue, "Nitrogen (N)"),
            _buildLegendItem(Colors.orange, "Phosphorus (P)"),
            _buildLegendItem(Colors.purple, "Potassium (K)"),
          ],
        ),
      ],
    );
  }

  LineChartBarData _makeLine(List<double> data, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
