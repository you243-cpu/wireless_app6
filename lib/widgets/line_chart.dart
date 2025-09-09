import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartWidget extends StatefulWidget {
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
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  final TransformationController _controller = TransformationController();

  void _resetZoom() {
    setState(() {
      _controller.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int dataLength = widget.data.length;

    return Stack(
      alignment: Alignment.topRight,
      children: [
        GestureDetector(
          onDoubleTap: _resetZoom,
          child: SizedBox(
            height: 350,
            child: InteractiveViewer(
              transformationController: _controller,
              panEnabled: true,
              scaleEnabled: true,
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
                          if (index < 0 || index >= widget.timestamps.length) {
                            return const SizedBox();
                          }
                          String formatted = DateFormat("MM-dd")
                              .format(widget.timestamps[index]);
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
                        widget.data.length,
                        (i) => FlSpot(i.toDouble(), widget.data[i]),
                      ),
                      isCurved: true,
                      color: widget.color,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: ElevatedButton(
            onPressed: _resetZoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Reset Zoom"),
          ),
        ),
      ],
    );
  }
}
