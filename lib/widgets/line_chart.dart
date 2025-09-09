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

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: (data.isEmpty ? 0 : (data.reduce((a, b) => a < b ? a : b))) - 1,
        maxY: (data.isEmpty ? 10 : (data.reduce((a, b) => a > b ? a : b))) + 1,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (timestamps.isEmpty ? 1 : (timestamps.length ~/ 5).toDouble()).clamp(1, 10).toDouble(),
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= timestamps.length) return const SizedBox.shrink();
                return Text(DateFormat("HH:mm").format(timestamps[index]), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
            isCurved: true,
            color: color,
            barWidth: 2,
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }
}
