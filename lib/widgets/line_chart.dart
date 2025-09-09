import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final List<DateTime> timestamps;
  final Color color;
  final String label;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.timestamps,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final int dataLength = data.length;

    return SizedBox(
      height: 350,
      child: InteractiveViewer(
        panEnabled: true, // ✅ drag/scroll
        scaleEnabled: true, // ✅ pinch-to-zoom
        minScale: 1,
        maxScale: 5,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(enabled: true),
            clipData: FlClipData.none(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (dataLength / 6).floorToDouble(),
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index < 0 || index >= timestamps.length) {
                      return const SizedBox();
                    }
                    String formatted =
                        DateFormat("MM-dd").format(timestamps[index]);
                    return Text(formatted,
                        style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
            ),
            minX: 0,
            maxX: (dataLength - 1).toDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  data.length,
                  (i) => FlSpot(i.toDouble(), data[i]),
                ),
                isCurved: true,
                color: color,
                barWidth: 2,
                dotData: FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
