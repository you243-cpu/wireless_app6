import 'package:flutter/material.dart';
import '../widgets/line_chart.dart';
import '../widgets/multi_line_chart.dart';

class GraphScreen extends StatefulWidget {
  final List<double> pHReadings;
  final List<double> nReadings;
  final List<double> pReadings;
  final List<double> kReadings;
  final List<double> temperatureReadings;
  final List<double> humidityReadings;
  final List<double> ecReadings;
  final List<DateTime> timestamps;

  const GraphScreen({
    super.key,
    required this.pHReadings,
    required this.nReadings,
    required this.pReadings,
    required this.kReadings,
    required this.temperatureReadings,
    required this.humidityReadings,
    required this.ecReadings,
    required this.timestamps,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  double zoomLevel = 1;
  int scrollIndex = 0;

  void zoomIn() {
    setState(() {
      if (zoomLevel < 5) zoomLevel += 1.0;
    });
  }

  void zoomOut() {
    setState(() {
      if (zoomLevel > 1) zoomLevel -= 1.0;
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final tabLabelColor = isDark ? Colors.tealAccent : Colors.green;
    final unselectedTabColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final iconColor = isDark ? Colors.tealAccent : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Graphs"),
        backgroundColor: isDark ? Colors.black : Colors.green[100],
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Column(
        children: [
          // Zoom & Scroll controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: zoomIn, icon: Icon(Icons.zoom_in, color: iconColor)),
              IconButton(onPressed: zoomOut, icon: Icon(Icons.zoom_out, color: iconColor)),
              IconButton(onPressed: scrollLeft, icon: Icon(Icons.arrow_left, color: iconColor)),
              IconButton(onPressed: scrollRight, icon: Icon(Icons.arrow_right, color: iconColor)),
            ],
          ),
          Expanded(
            child: DefaultTabController(
              length: 8, // 5 original + 3 new readings
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: tabLabelColor,
                    unselectedLabelColor: unselectedTabColor,
                    indicatorColor: tabLabelColor,
                    tabs: const [
                      Tab(text: "pH"),
                      Tab(text: "N"),
                      Tab(text: "P"),
                      Tab(text: "K"),
                      Tab(text: "Temperature"),
                      Tab(text: "Humidity"),
                      Tab(text: "EC"),
                      Tab(text: "All"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        LineChartWidget(
                          data: widget.pHReadings,
                          color: Colors.green,
                          label: "pH",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: widget.nReadings,
                          color: Colors.blue,
                          label: "N",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: widget.pReadings,
                          color: Colors.orange,
                          label: "P",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: widget.kReadings,
                          color: Colors.purple,
                          label: "K",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: widget.temperatureReadings,
                          color: Colors.red,
                          label: "Temperature",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: widget.humidityReadings,
                          color: Colors.cyan,
                          label: "Humidity",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: widget.ecReadings,
                          color: Colors.indigo,
                          label: "EC",
                          timestamps: widget.timestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        MultiLineChartWidget(
                          pHData: widget.pHReadings,
                          nData: widget.nReadings,
                          pData: widget.pReadings,
                          kData: widget.kReadings,
                          temperatureData: widget.temperatureReadings,
                          humidityData: widget.humidityReadings,
                          ecData: widget.ecReadings,
                          timestamps: widget.timestamps,
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
