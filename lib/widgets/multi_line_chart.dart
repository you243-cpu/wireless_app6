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
    ].reduce((a, b) => a < b ? a : b); // shortest series for safety

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(enabled: true), // 👆 zoom & scroll
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (dataLength / 6).floorToDouble(), // ~6–7 labels
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= timestamps.length) {
                  return const SizedBox();
                }
                String formatted =
                    DateFormat("MM-dd").format(timestamps[index]);
                return Text(formatted, style: const TextStyle(fontSize: 10));
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
              pHData.length,
              (i) => FlSpot(i.toDouble(), pHData[i]),
            ),
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(
              nData.length,
              (i) => FlSpot(i.toDouble(), nData[i]),
            ),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(
              pData.length,
              (i) => FlSpot(i.toDouble(), pData[i]),
            ),
            isCurved: true,
            color: Colors.orange,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(
              kData.length,
              (i) => FlSpot(i.toDouble(), kData[i]),
            ),
            isCurved: true,
            color: Colors.purple,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
