import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MultiLineChart extends StatelessWidget {
  final List<double> pHReadings, nReadings, pReadings, kReadings;
  final List<DateTime> timestamps;

  const MultiLineChart({
    super.key,
    required this.pHReadings,
    required this.nReadings,
    required this.pReadings,
    required this.kReadings,
    required this.timestamps,
  });

  String _formatTimestamp(int index) {
    if (index < 0 || index >= timestamps.length) return "";
    final dt = timestamps[index];
    return DateFormat("MM-dd HH:mm").format(dt);
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

  LineChartBarData _makeLine(List<double> data, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allData = [...pHReadings, ...nReadings, ...pReadings, ...kReadings];

    return Column(
      children: [
        Expanded(
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
                        return Text(_formatTimestamp(index), style: const TextStyle(fontSize: 10));
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey, width: 1)),
              minX: 0,
              maxX: (pHReadings.length - 1).toDouble(),
              minY: _getMinY(allData),
              maxY: _getMaxY(allData),
              lineBarsData: [
                _makeLine(pHReadings, Colors.green),
                _makeLine(nReadings, Colors.blue),
                _makeLine(pReadings, Colors.orange),
                _makeLine(kReadings, Colors.purple),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 20,
          children: const [
            Legend(color: Colors.green, text: "pH"),
            Legend(color: Colors.blue, text: "N"),
            Legend(color: Colors.orange, text: "P"),
            Legend(color: Colors.purple, text: "K"),
          ],
        ),
      ],
    );
  }
}

class Legend extends StatelessWidget {
  final Color color;
  final String text;
  const Legend({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 15, height: 15, color: color),
        const SizedBox(width: 5),
        Text(text),
      ],
    );
  }
}
