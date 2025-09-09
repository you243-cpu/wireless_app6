import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MultiLineChartWidget extends StatelessWidget {
  final List<double> pHData;
  final List<double> nData;
  final List<double> pData;
  final List<double> kData;
  final List<DateTime> timestamps;

  const MultiLineChartWidget({
    super.key,
    required this.pHData,
    required this.nData,
    required this.pData,
    required this.kData,
    required this.timestamps,
  });

  @override
  Widget build(BuildContext context) {
    final int dataLength = [
      pHData.length,
      nData.length,
      pData.length,
      kData.length,
    ].reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: 350,
          child: InteractiveViewer(
            panEnabled: true, // ✅ drag to scroll
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
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 40),
                  ),
                ),
                minX: 0,
                maxX: (dataLength - 1).toDouble(),
                lineBarsData: [
                  _makeLine(pHData, Colors.green),
                  _makeLine(nData, Colors.blue),
                  _makeLine(pData, Colors.orange),
                  _makeLine(kData, Colors.purple),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: const [
            _LegendItem(color: Colors.green, label: "pH"),
            _LegendItem(color: Colors.blue, label: "N"),
            _LegendItem(color: Colors.orange, label: "P"),
            _LegendItem(color: Colors.purple, label: "K"),
          ],
        ),
      ],
    );
  }

  LineChartBarData _makeLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: false),
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
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
