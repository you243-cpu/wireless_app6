import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MultiLineChartWidget extends StatefulWidget {
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
  State<MultiLineChartWidget> createState() => _MultiLineChartWidgetState();
}

class _MultiLineChartWidgetState extends State<MultiLineChartWidget> {
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
        // 📌 Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green, "pH"),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, "N"),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orange, "P"),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.purple, "K"),
            ],
          ),
        ),

        // 📈 Chart
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              minX: _minX,
              maxX: _maxX,
              minY: 0,
              maxY: [
                ...widget.pHData,
                ...widget.nData,
                ...widget.pData,
                ...widget.kData,
              ].reduce((a, b) => a > b ? a : b),
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
                _buildLine(widget.pHData, Colors.green),
                _buildLine(widget.nData, Colors.blue),
                _buildLine(widget.pData, Colors.orange),
                _buildLine(widget.kData, Colors.purple),
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

  LineChartBarData _buildLine(List<double> data, Color color) {
    return LineChartBarData(
      spots: List.generate(
        data.length,
        (i) => FlSpot(i.toDouble(), data[i]),
      ),
      isCurved: true,
      color: color,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
