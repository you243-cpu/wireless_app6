// lib/screens/heatmap_screen.dart
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';
import '../widgets/heatmap_3d.dart';
import '../widgets/heatmap_2d.dart';
import '../main.dart';

class HeatmapScreen extends StatefulWidget {
  final List<double> pHReadings;
  final List<double> temperatureReadings;
  final List<double> humidityReadings;
  final List<double> ecReadings;
  final List<double> nReadings;
  final List<double> pReadings;
  final List<double> kReadings;
  final List<DateTime> timestamps;

  const HeatmapScreen({
    super.key,
    required this.pHReadings,
    required this.temperatureReadings,
    required this.humidityReadings,
    required this.ecReadings,
    required this.nReadings,
    required this.pReadings,
    required this.kReadings,
    required this.timestamps,
  });

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final HeatmapService _svc = HeatmapService();
  final Heatmap3DController _cameraController = Heatmap3DController();

  String _metric = 'pH';
  List<List<double>> _grid = [];
  bool _show3D = true;
  double _sliderValue = 1.0; // 1.0 = latest

  final int _defaultCols = 40;
  final int _defaultRows = 40;

  @override
  void initState() {
    super.initState();
    _loadCsvAndInit();
  }

  void _loadCsvAndInit() {
    // Set points in HeatmapService
    List<HeatPoint> points = [];
    for (int i = 0; i < widget.timestamps.length; i++) {
      points.add(HeatPoint(
        t: widget.timestamps[i],
        lat: 0, // placeholder if no lat/lon
        lon: 0,
        pH: widget.pHReadings[i],
        temp: widget.temperatureReadings[i],
        humidity: widget.humidityReadings[i],
        ec: widget.ecReadings[i],
        n: widget.nReadings[i],
        p: widget.pReadings[i],
        k: widget.kReadings[i],
      ));
    }
    _svc.setPoints(points);
    _updateGrid();
  }

  void _updateGrid() {
    if (_svc.points.isEmpty) return;

    // Compute current timestamp from slider (0..1)
    DateTime startTime = _svc.points.first.t;
    DateTime endTime = _svc.points.last.t;
    DateTime rangeEnd = startTime.add(Duration(
      milliseconds: ((endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch) * _sliderValue).toInt(),
    ));

    setState(() {
      _grid = _svc.createGrid(
        metric: _metric,
        start: startTime,
        end: rangeEnd,
        cols: _defaultCols,
        rows: _defaultRows,
      );
    });
  }

  void _setMetric(String metric) {
    _metric = metric;
    _updateGrid();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ['pH', 'Temperature', 'EC', 'N', 'P', 'K', 'All'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Heatmap Viewer"),
        actions: [
          IconButton(
            icon: Icon(MyApp.themeNotifier.value == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              MyApp.themeNotifier.value =
                  MyApp.themeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Metric buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              children: metrics
                  .map(
                    (m) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _metric == m ? Colors.blue : null,
                      ),
                      onPressed: () => _setMetric(m),
                      child: Text(m),
                    ),
                  )
                  .toList(),
            ),
          ),

          // Timeline slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Past"),
                Expanded(
                  child: Slider(
                    value: _sliderValue,
                    min: 0.0,
                    max: 1.0,
                    divisions: widget.timestamps.length - 1,
                    label: "Time",
                    onChanged: (v) {
                      setState(() {
                        _sliderValue = v;
                        _updateGrid();
                      });
                    },
                  ),
                ),
                const Text("Now"),
              ],
            ),
          ),

          // 2D/3D toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _show3D = !_show3D),
                  child: Text(_show3D ? "Show 2D" : "Show 3D"),
                ),
                if (_show3D)
                  const SizedBox(width: 12),
                if (_show3D)
                  ElevatedButton.icon(
                    onPressed: () {
                      _cameraController.reset();
                      setState(() {}); // triggers rebuild
                    },
                    icon: const Icon(Icons.reset_tv),
                    label: const Text("Reset Camera"),
                  ),
              ],
            ),
          ),

          // Heatmap display
          Expanded(
            child: _grid.isEmpty
                ? const Center(child: Text("No data to display"))
                : _show3D
                    ? Heatmap3DViewer(
                        grid: _grid,
                        controller: _cameraController,
                        metricLabel: _metric,
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Heatmap2D(
                            grid: _grid,
                            cellSize: 8,
                            showGridLines: false,
                            metricLabel: _metric,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
