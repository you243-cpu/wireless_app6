import 'package:flutter/material.dart';
import '../widgets/soil_health_card.dart';
import '../widgets/gauges.dart';
import '../widgets/nutrient_card.dart';
import '../widgets/line_chart.dart';
import '../widgets/multi_line_chart.dart';
import '../services/csv_service.dart';
import '../services/sensor_service.dart';
import '../services/alert_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<double> pHReadings = [];
  List<double> nReadings = [];
  List<double> pReadings = [];
  List<double> kReadings = [];
  List<DateTime> timestamps = [];

  double soilHealthScore = 0;
  double moisture = 0;
  double temperature = 0;
  double N = 0, P = 0, K = 0;

  @override
  void initState() {
    super.initState();
    _loadCSVData();
  }

  Future<void> _loadCSVData() async {
    final result = await CSVService.loadCSV('assets/data_aug24.csv');
    setState(() {
      pHReadings = result['pH'] ?? [];
      nReadings = result['N'] ?? [];
      pReadings = result['P'] ?? [];
      kReadings = result['K'] ?? [];
      timestamps = result['timestamps']?.cast<DateTime>() ?? [];
    });

    // Update metrics
    if (pHReadings.isNotEmpty) {
      soilHealthScore = SensorService.calculateSoilHealth(
        pH: pHReadings.last,
        n: nReadings.last,
        p: pReadings.last,
        k: kReadings.last,
      );

      N = nReadings.last;
      P = pReadings.last;
      K = kReadings.last;

      // Example static gauges
      moisture = 65;
      temperature = 28;

      AlertService.checkAlerts(
        context,
        pH: pHReadings.last,
        soilHealth: soilHealthScore,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Soil Health Dashboard"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SoilHealthCard(score: soilHealthScore),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GaugeWidget(value: moisture, label: "Moisture", unit: "%"),
                GaugeWidget(value: temperature, label: "Temp", unit: "°C"),
              ],
            ),
            const SizedBox(height: 12),
            NutrientCard(N: N, P: P, K: K),
            const SizedBox(height: 12),
            LineChartWidget(
              data: pHReadings,
              timestamps: timestamps,
              label: "pH",
              color: Colors.green,
            ),
            LineChartWidget(
              data: nReadings,
              timestamps: timestamps,
              label: "Nitrogen (N)",
              color: Colors.blue,
            ),
            LineChartWidget(
              data: pReadings,
              timestamps: timestamps,
              label: "Phosphorus (P)",
              color: Colors.orange,
            ),
            LineChartWidget(
              data: kReadings,
              timestamps: timestamps,
              label: "Potassium (K)",
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
    );
  }
}
