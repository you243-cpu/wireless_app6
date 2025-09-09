import 'package:flutter/material.dart';
import '../widgets/line_chart.dart';
import '../widgets/multi_line_chart.dart';

class GraphScreen extends StatefulWidget {
  final List<double> pHReadings;
  final List<double> nReadings;
  final List<double> pReadings;
  final List<double> kReadings;
  final List<DateTime> timestamps;

  const GraphScreen({
    super.key,
    required this.pHReadings,
    required this.nReadings,
    required this.pReadings,
    required this.kReadings,
    required this.timestamps,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  double zoom = 1.0;
  double offset = 0.0;

  void _zoomIn() {
    setState(() => zoom = (zoom * 1.5).clamp(1.0, 10.0));
  }

  void _zoomOut() {
    setState(() => zoom = (zoom / 1.5).clamp(1.0, 10.0));
  }

  void _scrollLeft() {
    setState(() => offset = (offset - 10).clamp(0, widget.timestamps.length.toDouble()));
  }

  void _scrollRight() {
    setState(() => offset = (offset + 10).clamp(0, widget.timestamps.length.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📊 Sensor Graphs")),
      body: Column(
        children: [
          // Buttons for zoom + scroll
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 10,
              children: [
                ElevatedButton(onPressed: _zoomIn, child: const Text("Zoom In")),
                ElevatedButton(onPressed: _zoomOut, child: const Text("Zoom Out")),
                ElevatedButton(onPressed: _scrollLeft, child: const Text("← Scroll")),
                ElevatedButton(onPressed: _scrollRight, child: const Text("Scroll →")),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.green,
                    unselectedLabelColor: Colors.grey,
                    isScrollable: true,
                    tabs: [
                      Tab(text: "pH"),
                      Tab(text: "N"),
                      Tab(text: "P"),
                      Tab(text: "K"),
                      Tab(text: "All"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        LineChartWidget(data: widget.pHReadings, color: Colors.green, label: "pH", timestamps: widget.timestamps, zoom: zoom, offset: offset),
                        LineChartWidget(data: widget.nReadings, color: Colors.blue, label: "N", timestamps: widget.timestamps, zoom: zoom, offset: offset),
                        LineChartWidget(data: widget.pReadings, color: Colors.orange, label: "P", timestamps: widget.timestamps, zoom: zoom, offset: offset),
                        LineChartWidget(data: widget.kReadings, color: Colors.purple, label: "K", timestamps: widget.timestamps, zoom: zoom, offset: offset),
                        MultiLineChartWidget(
                          pHData: widget.pHReadings,
                          nData: widget.nReadings,
                          pData: widget.pReadings,
                          kData: widget.kReadings,
                          timestamps: widget.timestamps,
                          zoom: zoom,
                          offset: offset,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

