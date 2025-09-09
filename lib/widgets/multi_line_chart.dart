import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final TransformationController _controller = TransformationController();

  void _resetZoom() {
    setState(() {
      _controller.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int dataLength = [
      widget.pHData.length,
      widget.nData.length,
      widget.pData.length,
      widget.kData.length,
    ].reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        Stack(
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
                              if (index < 0 ||
                                  index >= widget.timestamps.length) {
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
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 40),
                        ),
                      ),
                      minX: 0,
                      maxX: (dataLength - 1).toDouble(),
                      lineBarsData: [
                        _makeLine(widget.pHData, Colors.green),
                        _makeLine(widget.nData, Colors.blue),
                        _makeLine(widget.pData, Colors.orange),
                        _makeLine(widget.kData, Colors.purple),
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
