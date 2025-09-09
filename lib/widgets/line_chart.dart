import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final Color color;
  final String label;
  final List<DateTime> timestamps;
  final double zoom;
  final double offset;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.color,
    required this.label,
    required this.timestamps,
    this.zoom = 1.0,
    this.offset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final length = data.length;
    if (length < 2) {
      return const Center(child: Text("Not enough data"));
    }

    final minX = offset;
    final maxX = (offset + (length / zoom)).clamp(0, length.toDouble());

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: data.reduce((a, b) => a < b ? a : b) - 1,
        maxY: data.reduce((a, b) => a > b ? a : b) + 1,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: ((maxX - minX) / 6).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= timestamps.length) return const SizedBox.shrink();
                return Text(
                  "${timestamps[index].month}/${timestamps[index].day}\n${timestamps[index].hour}:${timestamps[index].minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(length, (i) => FlSpot(i.toDouble(), data[i])),
            isCurved: true,
            color: color,
            dotData: const FlDotData(show: false),
          )
        ],
      ),
    );
  }
}
