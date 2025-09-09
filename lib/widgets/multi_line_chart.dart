import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MultiLineChartWidget extends StatelessWidget {
  final List<double> pHReadings;
  final List<double> nReadings;
  final List<double> pReadings;
  final List<double> kReadings;
  final List<DateTime> timestamps;

  const MultiLineChartWidget({
    super.key,
    required this.pHReadings,
    required this.nReadings,
    required this.pReadings,
    required this.kReadings,
    required this.timestamps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("All Parameters",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(show: true),
                  lineBarsData: [
                    _makeLine(pHReadings, Colors.green),
                    _makeLine(nReadings, Colors.blue),
                    _makeLine(pReadings, Colors.orange),
                    _makeLine(kReadings, Colors.purple),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _makeLine(List<double> data, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value);
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(show: false),
    );
  }
}
