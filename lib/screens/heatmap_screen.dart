// lib/screens/heatmap_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../services/heatmap_service.dart';
import '../widgets/heatmap_3d.dart';
import '../widgets/heatmap_2d.dart';
import '../main.dart';
import '../providers/csv_data_provider.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final HeatmapService _svc = HeatmapService();

  String _metric = 'pH';
  double _sliderValue = 1.0;
  List<List<double>> _grid = [];
  bool _show3dView = false; // Default to 2D view
  String _gltfPath = '';

  final List<DateTime> _timePoints = [];
  final Map<DateTime, List<List<double>>> _gridSnapshots = {};

  double _minValue = 0;
  double _maxValue = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CSVDataProvider>();
    _initializeHeatmap(provider);
  }

  void _initializeHeatmap(CSVDataProvider provider) {
    final points = <HeatPoint>[];
    for (int i = 0; i < provider.timestamps.length; i++) {
      points.add(HeatPoint(
        t: provider.timestamps[i],
        lat: provider.latitudes[i],
        lon: provider.longitudes[i],
        pH: provider.pH[i],
        temp: provider.temperature[i],
        humidity: provider.humidity[i],
        ec: provider.ec[i],
        n: provider.n[i],
        p: provider.p[i],
        k: provider.k[i],
      ));
    }

    _svc.setPoints(points);
    _precomputeSnapshots(provider);
  }

  Future<void> _precomputeSnapshots(CSVDataProvider provider) async {
    _gridSnapshots.clear();
    _timePoints.clear();
    final allTimestamps = provider.timestamps.toSet().toList()..sort();
    
    for (final t in allTimestamps) {
      final grid = _svc.createGrid(metric: _metric, start: allTimestamps.first, end: t);
      _gridSnapshots[t] = grid;
      _timePoints.add(t);
    }
    
    // Generate GLTF for the initial state
    if (_timePoints.isNotEmpty) {
      await _generateGltfFile(_gridSnapshots[_timePoints.first]!, _metric);
    }
    _updateGridAndValues();
  }

  Future<void> _generateGltfFile(List<List<double>> grid, String metricLabel) async {
    // This is a placeholder. A full implementation would involve:
    // 1. Creating a GLTF object programmatically from your grid data.
    // 2. Exporting the GLTF object to a file.
    // 3. Getting the path to the saved file.
    
    // As a temporary solution, we create a placeholder file to prevent build errors.
    // A full GLTF generation from your data is a complex task.
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/heatmap.gltf');
    await file.writeAsString(jsonEncode({'asset': {'version': '2.0'}}));

    setState(() {
      _gltfPath = file.path;
    });
  }

  void _updateGridAndValues() {
    if (_timePoints.isNotEmpty) {
      final index = (_timePoints.length * _sliderValue).clamp(0, _timePoints.length - 1).round();
      final time = _timePoints[index];
      final newGrid = _gridSnapshots[time]!;
      
      double minV = double.infinity, maxV = -double.infinity;
      final values = newGrid.expand((r) => r).where((v) => !v.isNaN).toList();
      if (values.isNotEmpty) {
        minV = values.reduce((a, b) => a < b ? a : b);
        maxV = values.reduce((a, b) => a > b ? a : b);
      } else {
        minV = 0;
        maxV = 1;
      }
      
      setState(() {
        _grid = newGrid;
        _minValue = minV;
        _maxValue = maxV;
        _generateGltfFile(newGrid, _metric);
      });
    }
  }

  void _setMetric(String metric) {
    setState(() {
      _metric = metric;
      _precomputeSnapshots(context.read<CSVDataProvider>());
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
      _updateGridAndValues();
    });
  }

  void _toggleView() {
    setState(() {
      _show3dView = !_show3dView;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CSVDataProvider>();
    final metrics = ['pH', 'Temperature', 'EC', 'N', 'P', 'K', 'All'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!provider.hasData) {
      return const Scaffold(
        body: Center(child: Text("No data available.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Heatmap Viewer"),
        actions: [
          IconButton(
            icon: Icon(_show3dView ? Icons.view_in_ar : Icons.grid_on),
            onPressed: _toggleView,
            tooltip: _show3dView ? 'Switch to 2D View' : 'Switch to 3D View',
          ),
          IconButton(
            icon: Icon(MyApp.themeNotifier.value == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              MyApp.themeNotifier.value = MyApp.themeNotifier.value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
          if (_timePoints.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Slider(
                    value: _sliderValue,
                    min: 0.0,
                    max: 1.0,
                    divisions: _timePoints.length > 1 ? _timePoints.length - 1 : 1,
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
          Expanded(
            child: _grid.isEmpty
                ? const Center(child: Text("No data yet"))
                : _show3dView
                    ? Heatmap3DViewer(
                        gltfModelPath: _gltfPath,
                      )
                    : Heatmap2D(
                        grid: _grid,
                        metricLabel: _metric,
                        minValue: _minValue,
                        maxValue: _maxValue,
                      ),
          ),
        ],
      ),
    );
  }
}
