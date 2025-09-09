import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartWidget extends StatelessWidget {
  final List<FlSpot> spots;
  final String title;
  final int scrollIndex;

  const LineChartWidget({
    Key? key,
    required this.spots,
    required this.title,
    this.scrollIndex = 0, // ✅ added scrollIndex with default
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Limit visible x values based on scrollIndex
    int windowSize = 7; // show 7 points at a time
    int start = scrollIndex * windowSize;
    int end = (start + windowSize).clamp(0, spots.length);

    final visibleSpots = spots.sublist(
      start < spots.length ? start : 0,
      end,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final int index = value.toInt();
                      if (index >= 0 && index < visibleSpots.length) {
                        return Text("D${index + 1}");
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: visibleSpots,
                  isCurved: true,
                  color: Colors.blue,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
