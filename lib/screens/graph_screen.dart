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
  int zoomLevel = 1; // 1 = full view
  int scrollIndex = 0;

  void zoomIn() {
    setState(() {
      if (zoomLevel < 5) zoomLevel++;
    });
  }

  void zoomOut() {
    setState(() {
      if (zoomLevel > 1) zoomLevel--;
    });
  }

  void scrollLeft() {
    setState(() {
      if (scrollIndex > 0) scrollIndex--;
    });
  }

  void scrollRight() {
    setState(() {
      if (scrollIndex < widget.timestamps.length - 10) scrollIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pHReadings = widget.pHReadings;
    final nReadings = widget.nReadings;
    final pReadings = widget.pReadings;
    final kReadings = widget.kReadings;
    final timestamps = widget.timestamps;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Graphs"),
      ),
      body: Column(
        children: [
          // Zoom & Scroll controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: zoomIn, icon: const Icon(Icons.zoom_in)),
              IconButton(onPressed: zoomOut, icon: const Icon(Icons.zoom_out)),
              IconButton(onPressed: scrollLeft, icon: const Icon(Icons.arrow_left)),
              IconButton(onPressed: scrollRight, icon: const Icon(Icons.arrow_right)),
            ],
          ),
          Expanded(
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    labelColor: Colors.green,
                    unselectedLabelColor: Colors.grey,
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
                      physics: const NeverScrollableScrollPhysics(), // disable swipe
                      children: [
                        LineChartWidget(
                          data: pHReadings,
                          color: Colors.green,
                          label: "pH",
                          timestamps: timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: nReadings,
                          color: Colors.blue,
                          label: "N",
                          timestamps: timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: pReadings,
                          color: Colors.orange,
                          label: "P",
                          timestamps: timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: kReadings,
                          color: Colors.purple,
                          label: "K",
                          timestamps: timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        MultiLineChartWidget(
                          pHData: pHReadings,
                          nData: nReadings,
                          pData: pReadings,
                          kData: kReadings,
                          timestamps: timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
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
