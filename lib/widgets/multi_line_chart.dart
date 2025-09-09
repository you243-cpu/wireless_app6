import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MultiLineChartWidget extends StatelessWidget {
  final List<double> pHData;
  final List<double> nData;
  final List<double> pData;
  final List<double> kData;

  const MultiLineChartWidget({
    super.key,
    required this.pHData,
    required this.nData,
    required this.pData,
    required this.kData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("All Parameters",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    _buildLine(pHData, Colors.green),
                    _buildLine(nData, Colors.blue),
                    _buildLine(pData, Colors.orange),
                    _buildLine(kData, Colors.purple),
                  ],
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<double> data, Color color) {
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
