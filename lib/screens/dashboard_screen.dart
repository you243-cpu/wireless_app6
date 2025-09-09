import 'package:flutter/material.dart';
import 'package:wireless_appf/widgets/soil_health_card.dart';
import 'package:wireless_appf/widgets/gauges.dart';
import 'package:wireless_appf/widgets/nutrient_card.dart';
import 'package:wireless_appf/widgets/line_chart.dart';
import 'package:wireless_appf/widgets/multi_line_chart.dart';

// Import services with aliases to avoid conflicts
import 'package:wireless_appf/services/csv_service.dart' as csv;
import 'package:wireless_appf/services/sensor_service.dart' as sensor;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<double> pHReadings = [];
  List<double> nReadings = [];
  List<double> pReadings = [];
  List<double> kReadings = [];
  double soilHealthScore = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final result = await csv.CSVService.loadCSV('assets/data_aug24.csv');

    setState(() {
      // Cast to List<double> safely
      pHReadings = (result['pH'] ?? []).map<double>((e) => e.toDouble()).toList();
      nReadings = (result['N'] ?? []).map<double>((e) => e.toDouble()).toList();
      pReadings = (result['P'] ?? []).map<double>((e) => e.toDouble()).toList();
      kReadings = (result['K'] ?? []).map<double>((e) => e.toDouble()).toList();

      if (pHReadings.isNotEmpty &&
          nReadings.isNotEmpty &&
          pReadings.isNotEmpty &&
          kReadings.isNotEmpty) {
        soilHealthScore = sensor.SensorService.calculateSoilHealth(
          pH: pHReadings.last,
          n: nReadings.last,
          p: pReadings.last,
          k: kReadings.last,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Soil Dashboard"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoilHealthCard(score: soilHealthScore),
            const SizedBox(height: 16),

            NutrientCard(
              N: nReadings.isNotEmpty ? nReadings.last : 0,
              P: pReadings.isNotEmpty ? pReadings.last : 0,
              K: kReadings.isNotEmpty ? kReadings.last : 0,
            ),
            const SizedBox(height: 16),

            if (pHReadings.isNotEmpty)
              LineChartWidget(
                data: pHReadings,
                title: "pH Levels",
                color: Colors.green,
              ),
            if (nReadings.isNotEmpty)
              LineChartWidget(
                data: nReadings,
                title: "Nitrogen (N)",
                color: Colors.blue,
              ),
            if (pReadings.isNotEmpty)
              LineChartWidget(
                data: pReadings,
                title: "Phosphorus (P)",
                color: Colors.orange,
              ),
            if (kReadings.isNotEmpty)
              LineChartWidget(
                data: kReadings,
                title: "Potassium (K)",
                color: Colors.purple,
              ),

            if (pHReadings.isNotEmpty &&
                nReadings.isNotEmpty &&
                pReadings.isNotEmpty &&
                kReadings.isNotEmpty)
              MultiLineChartWidget(
                pHData: pHReadings,
                nData: nReadings,
                pData: pReadings,
                kData: kReadings,
              ),
          ],
        ),
      ),
    );
  }
}
