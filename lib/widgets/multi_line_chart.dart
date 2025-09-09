import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MultiLineChartWidget extends StatelessWidget {
  final List<double> pHData;
  final List<double> nData;
  final List<double> pData;
  final List<double> kData;
  final List<DateTime> timestamps;

  final double zoomLevel;
  final int scrollOffset;

  const MultiLineChartWidget({
    super.key,
    required this.pHData,
    required this.nData,
    required this.pData,
    required this.kData,
    required this.timestamps,
    this.zoomLevel = 1.0,
    this.scrollOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (timestamps.isEmpty) {
      return const Center(child: Text("No data"));
    }

    int visibleCount = (timestamps.length ~/ zoomLevel).clamp(6, timestamps.length);
    int start = scrollOffset.clamp(0, (timestamps.length - visibleCount).clamp(0, timestamps.length));
    int end = (start + visibleCount).clamp(0, timestamps.length);

    final shownTimestamps = timestamps.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
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
                  _buildLine(pHData.sublist(start, end), Colors.green),
                  _buildLine(nData.sublist(start, end), Colors.blue),
                  _buildLine(pData.sublist(start, end), Colors.orange),
                  _buildLine(kData.sublist(start, end), Colors.purple),
                ],
              ),
            ),
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 12,
            children: const [
              _LegendItem(color: Colors.green, label: "pH"),
              _LegendItem(color: Colors.blue, label: "Nitrogen"),
              _LegendItem(color: Colors.orange, label: "Phosphorus"),
              _LegendItem(color: Colors.purple, label: "Potassium"),
            ],
          ),
        ),
      ],
    );
  }

  LineChartBarData _buildLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
