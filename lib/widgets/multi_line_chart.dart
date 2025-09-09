import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final List<DateTime> timestamps;
  final String label;
  final Color color;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.timestamps,
    required this.label,
    required this.color,
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

  @override
  Widget build(BuildContext context) {
    return LineChart(
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
                  return Text(_formatTimestamp(index), style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey, width: 1)),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: _getMinY(data),
        maxY: _getMaxY(data),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
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

