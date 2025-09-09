import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class LineChartWidget extends StatefulWidget {
  final List<double> data;
  final Color color;
  final String label;
  final List<DateTime> timestamps;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.color,
    required this.label,
    required this.timestamps,
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  double _minX = 0;
  double _maxX = 20;

  void _zoomIn() {
    setState(() {
      final range = (_maxX - _minX) * 0.8;
      _maxX = _minX + range;
    });
  }

  void _zoomOut() {
    setState(() {
      final range = (_maxX - _minX) / 0.8;
      _maxX = _minX + range;
      if (_maxX > widget.timestamps.length.toDouble()) {
        _maxX = widget.timestamps.length.toDouble();
      }
    });
  }

  void _scrollLeft() {
    setState(() {
      final shift = (_maxX - _minX) * 0.2;
      _minX = (_minX - shift).clamp(0, widget.timestamps.length.toDouble());
      _maxX = (_maxX - shift).clamp(0, widget.timestamps.length.toDouble());
    });
  }

  void _scrollRight() {
    setState(() {
      final shift = (_maxX - _minX) * 0.2;
      _minX = (_minX + shift).clamp(0, widget.timestamps.length.toDouble());
      _maxX = (_maxX + shift).clamp(0, widget.timestamps.length.toDouble());
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.timestamps.isNotEmpty) {
      _maxX = widget.timestamps.length.toDouble().clamp(0, 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 📈 Chart
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              minX: _minX,
              maxX: _maxX,
              minY: 0,
              maxY: widget.data.isEmpty
                  ? 1
                  : widget.data.reduce((a, b) => a > b ? a : b),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: ((_maxX - _minX) / 6).clamp(1, double.infinity),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= widget.timestamps.length) {
                        return const SizedBox.shrink();
                      }
                      final time = widget.timestamps[index];
                      return Text(
                        "${time.month}/${time.day}\n${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    widget.data.length,
                    (i) => FlSpot(i.toDouble(), widget.data[i]),
                  ),
                  isCurved: true,
                  color: widget.color,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),

        // 🔍 Zoom & Scroll Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.zoom_in), onPressed: _zoomIn),
            IconButton(icon: const Icon(Icons.zoom_out), onPressed: _zoomOut),
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _scrollLeft),
            IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _scrollRight),
          ],
        ),
      ],
    );
  }
}
