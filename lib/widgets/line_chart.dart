import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final List<DateTime> timestamps;
  final String label;
  final Color color;

  final double zoomLevel;
  final int scrollIndex; // renamed from scrollOffset

  const LineChartWidget({
    super.key,
    required this.data,
    required this.timestamps,
    required this.label,
    required this.color,
    this.zoomLevel = 1.0,
    this.scrollIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No data"));
    }

    // Determine visible window
    int visibleCount = (timestamps.length ~/ zoomLevel).clamp(6, timestamps.length);
    int start = scrollIndex.clamp(0, (timestamps.length - visibleCount).clamp(0, timestamps.length));
    int end = (start + visibleCount).clamp(0, timestamps.length);

    final shownData = data.sublist(start, end);
    final shownTimestamps = timestamps.sublist(start, end);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                // Only ~6–7 date labels
                interval: (shownTimestamps.length / 6).floorToDouble().clamp(1, shownTimestamps.length.toDouble()),
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index < 0 || index >= shownTimestamps.length) return const SizedBox.shrink();
                  return Text(
                    "${shownTimestamps[index].month}/${shownTimestamps[index].day}",
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(shownData.length, (i) => FlSpot(i.toDouble(), shownData[i])),
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
