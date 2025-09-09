import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: [
          ...pHData,
          ...nData,
          ...pData,
          ...kData,
        ].isEmpty
            ? 10
            : [
                ...pHData,
                ...nData,
                ...pData,
                ...kData,
              ].reduce((a, b) => a > b ? a : b) +
                2,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (timestamps.isEmpty ? 1 : (timestamps.length ~/ 5).toDouble()).clamp(1, 10),
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
          _makeLine(pHData, Colors.green),
          _makeLine(nData, Colors.blue),
          _makeLine(pData, Colors.orange),
          _makeLine(kData, Colors.purple),
        ],
      ),
    );
  }

  LineChartBarData _makeLine(List<double> data, Color color) {
    return LineChartBarData(
      spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
      isCurved: true,
      color: color,
      barWidth: 2,
      belowBarData: BarAreaData(show: false),
    );
  }
}
