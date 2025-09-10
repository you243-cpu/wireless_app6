// lib/screens/heatmap_screen.dart
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';
import '../widgets/heatmap_3d.dart';
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
  DateTimeRange? _range;
  double _sliderValue = 1.0; // 0 = start, 1 = latest
  List<List<double>> _grid = [];

  // Precomputed grid snapshots for smooth slider updates
  final List<DateTime> _timePoints = [];
  final Map<DateTime, List<List<double>>> _gridSnapshots = {};

  @override
  void initState() {
    super.initState();
    _initializeHeatmap();
  }

  void _initializeHeatmap() {
    final points = <HeatPoint>[];
    for (int i = 0; i < widget.timestamps.length; i++) {
      points.add(HeatPoint(
        t: widget.timestamps[i],
        lat: 0.0, // replace with actual lat if available
        lon: 0.0, // replace with actual lon if available
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

    if (widget.timestamps.isNotEmpty) {
      _range = DateTimeRange(start: widget.timestamps.first, end: widget.timestamps.last);
      _precomputeSnapshots();
    }
  }

  /// Precompute grid snapshots for each timestamp
  void _precomputeSnapshots() {
    _gridSnapshots.clear();
    _timePoints.clear();
    for (final t in widget.timestamps) {
      final grid = _svc.createGrid(
        metric: _metric,
        start: widget.timestamps.first,
        end: t,
      );
      _gridSnapshots[t] = grid;
      _timePoints.add(t);
    }
    setState(() {
      _grid = _gridSnapshots[_timePoints.last]!;
      _sliderValue = 1.0;
    });
  }

  void _setMetric(String metric) {
    setState(() {
      _metric = metric;
      _precomputeSnapshots();
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
      // Find closest timestamp for slider
      final index = (_timePoints.length * value).clamp(0, _timePoints.length - 1).round();
      final time = _timePoints[index];
      _grid = _gridSnapshots[time]!;
    });
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
            icon: Icon(
              MyApp.themeNotifier.value == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: metrics.map((m) {
                final isSelected = _metric == m;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.blue : null,
                    ),
                    onPressed: () => _setMetric(m),
                    child: Text(m),
                  ),
                );
              }).toList(),
            ),
          ),

          // Timeline slider
          if (_range != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Slider(
                    value: _sliderValue,
                    min: 0.0,
                    max: 1.0,
                    divisions: _timePoints.length - 1,
                    label:
                        "${_timePoints[(_timePoints.length * _sliderValue).clamp(0, _timePoints.length - 1).round()]}".split(' ')[0],
                    onChanged: _onSliderChanged,
                  ),
                  Text(
                    "Showing data up to: ${_timePoints[(_timePoints.length * _sliderValue).clamp(0, _timePoints.length - 1).round()]}",
                  ),
                ],
              ),
            ),

          // 3D Heatmap
          Expanded(
            child: _grid.isEmpty
                ? const Center(child: Text("No data yet"))
                : Heatmap3DViewer(
                    grid: _grid,
                    controller: _cameraController,
                    metricLabel: _metric,
                  ),
          ),
        ],
      ),
    );
  }
}
