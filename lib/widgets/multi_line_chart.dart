import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MultiLineChartWidget extends StatelessWidget {
  final List<double> pHData;
  final List<double> nData;
  final List<double> pData;
  final List<double> kData;
  final List<double> temperatureData;
  final List<double> humidityData;
  final List<double> ecData;
  final List<DateTime> timestamps;

  final double zoomLevel;
  final int scrollIndex;

  const MultiLineChartWidget({
    super.key,
    required this.pHData,
    required this.nData,
    required this.pData,
    required this.kData,
    required this.temperatureData,
    required this.humidityData,
    required this.ecData,
    required this.timestamps,
    this.zoomLevel = 1.0,
    this.scrollIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (timestamps.isEmpty) {
      return const Center(child: Text("No data"));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final axisColor = isDark ? Colors.white70 : Colors.black87;
    final gridColor = isDark ? Colors.white24 : Colors.black26;

    int visibleCount = (timestamps.length ~/ zoomLevel).clamp(6, timestamps.length);
    int start = scrollIndex.clamp(0, (timestamps.length - visibleCount).clamp(0, timestamps.length));
    int end = (start + visibleCount).clamp(0, timestamps.length);

    final shownTimestamps = timestamps.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5),
                  getDrawingVerticalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (shownTimestamps.length / 6)
                          .floorToDouble()
                          .clamp(1, shownTimestamps.length.toDouble()),
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= shownTimestamps.length) return const SizedBox.shrink();
                        return Text(
                          "${shownTimestamps[index].month}/${shownTimestamps[index].day}",
                          style: TextStyle(fontSize: 10, color: axisColor),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(fontSize: 10, color: axisColor),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: gridColor),
                ),
                lineBarsData: [
                  _buildLine(pHData.sublist(start, end), Colors.green),
                  _buildLine(nData.sublist(start, end), Colors.blue),
                  _buildLine(pData.sublist(start, end), Colors.orange),
                  _buildLine(kData.sublist(start, end), Colors.purple),
                  _buildLine(temperatureData.sublist(start, end), Colors.red),
                  _buildLine(humidityData.sublist(start, end), Colors.cyan),
                  _buildLine(ecData.sublist(start, end), Colors.indigo),
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
            children: [
              _LegendItem(color: Colors.green, label: "pH", textColor: axisColor),
              _LegendItem(color: Colors.blue, label: "Nitrogen", textColor: axisColor),
              _LegendItem(color: Colors.orange, label: "Phosphorus", textColor: axisColor),
              _LegendItem(color: Colors.purple, label: "Potassium", textColor: axisColor),
              _LegendItem(color: Colors.red, label: "Temperature", textColor: axisColor),
              _LegendItem(color: Colors.cyan, label: "Humidity", textColor: axisColor),
              _LegendItem(color: Colors.indigo, label: "EC", textColor: axisColor),
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
  final Color textColor;

  const _LegendItem({required this.color, required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textColor)),
      ],
    );
  }
}
