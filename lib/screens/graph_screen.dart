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

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Zoom/Scroll control
  double zoomLevel = 1.0; // 1 = normal, >1 = zoomed
  int scrollOffset = 0;   // how far the window is shifted

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      zoomLevel = (zoomLevel * 1.5).clamp(1.0, 10.0);
    });
  }

  void _zoomOut() {
    setState(() {
      zoomLevel = (zoomLevel / 1.5).clamp(1.0, 10.0);
    });
  }

  void _scrollLeft() {
    setState(() {
      scrollOffset = (scrollOffset - 5).clamp(0, widget.timestamps.length);
    });
  }

  void _scrollRight() {
    setState(() {
      scrollOffset =
          (scrollOffset + 5).clamp(0, widget.timestamps.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Graphs"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "pH"),
            Tab(text: "N"),
            Tab(text: "P"),
            Tab(text: "K"),
            Tab(text: "All"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Zoom/Scroll buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: _zoomOut,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _scrollLeft,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _scrollRight,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // 🚫 disable swipe
              children: [
                LineChartWidget(
                  data: widget.pHReadings,
                  color: Colors.green,
                  label: "pH",
                  timestamps: widget.timestamps,
                  zoomLevel: zoomLevel,
                  scrollOffset: scrollOffset,
                ),
                LineChartWidget(
                  data: widget.nReadings,
                  color: Colors.blue,
                  label: "Nitrogen (N)",
                  timestamps: widget.timestamps,
                  zoomLevel: zoomLevel,
                  scrollOffset: scrollOffset,
                ),
                LineChartWidget(
                  data: widget.pReadings,
                  color: Colors.orange,
                  label: "Phosphorus (P)",
                  timestamps: widget.timestamps,
                  zoomLevel: zoomLevel,
                  scrollOffset: scrollOffset,
                ),
                LineChartWidget(
                  data: widget.kReadings,
                  color: Colors.purple,
                  label: "Potassium (K)",
                  timestamps: widget.timestamps,
                  zoomLevel: zoomLevel,
                  scrollOffset: scrollOffset,
                ),
                MultiLineChartWidget(
                  pHData: widget.pHReadings,
                  nData: widget.nReadings,
                  pData: widget.pReadings,
                  kData: widget.kReadings,
                  timestamps: widget.timestamps,
                  zoomLevel: zoomLevel,
                  scrollOffset: scrollOffset,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
