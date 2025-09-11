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
  final Heatmap3DController _cameraController = Heatmap3DController();

  String _metric = 'pH';
  double _sliderValue = 1.0;
  List<List<double>> _grid = [];
  bool _show3dView = true;
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
    await _generateGltfFile(_gridSnapshots[_timePoints.first]!, _metric);
    _updateGridAndValues();
  }

  Future<void> _generateGltfFile(List<List<double>> grid, String metricLabel) async {
    final vertices = <double>[];
    final colors = <double>[];
    final indices = <int>[];
    final rows = grid.length;
    final cols = grid[0].length;
    final cellScale = 0.5;

    final minV = _minValue, maxV = _maxValue;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final value = grid[r][c];
        if (value.isNaN) continue;

        final height = ((value - minV) / (maxV - minV)).clamp(0.0, 1.0);
        final color = valueToColor(value, minV, maxV, metricLabel);

        final x = (c - cols / 2 + 0.5) * cellScale;
        final z = (r - rows / 2 + 0.5) * cellScale;
        final y = height * 2.0;

        // Vertices for a simple cube, scaled by height
        // Front face
        vertices.addAll([x, 0, z, x + cellScale, 0, z, x + cellScale, y, z, x, y, z]);
        // Back face
        vertices.addAll([x, 0, z + cellScale, x + cellScale, 0, z + cellScale, x + cellScale, y, z + cellScale, x, y, z + cellScale]);
        // Other faces...
        // ... (This is a simplified example, a full cube would have 24 vertices)
        
        // Colors for each vertex
        for (int i = 0; i < 24; i++) {
          colors.addAll([color.red / 255, color.green / 255, color.blue / 255]);
        }
        
        // Indices for the cube, a simple example
        final offset = (r * cols + c) * 24;
        indices.addAll([
          0 + offset, 1 + offset, 2 + offset, 0 + offset, 2 + offset, 3 + offset,
          // ... (Indices for all other faces)
        ]);
      }
    }

    // A simplified GLTF structure (minimal)
    final gltfJson = {
      "asset": {"version": "2.0"},
      "scenes": [{"nodes": [0]}],
      "nodes": [{"mesh": 0}],
      "meshes": [{
        "primitives": [{
          "attributes": {
            "POSITION": 1,
            "COLOR_0": 2,
          },
          "indices": 0,
        }]
      }],
      "buffers": [{
        "uri": "data:application/octet-stream;base64,...", // Base64 encoded binary data
        "byteLength": 0
      }],
      "bufferViews": [],
      "accessors": []
    };
    
    // In a real implementation, you would need to:
    // 1. Create a binary buffer from vertices, colors, and indices.
    // 2. Base64 encode the buffer.
    // 3. Set the gltfJson's buffer URI and byteLength.
    // 4. Create proper buffer views and accessors.
    
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/heatmap.gltf');
    // For this example, we'll write a simple placeholder JSON
    await file.writeAsString(jsonEncode(gltfJson));
    
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
