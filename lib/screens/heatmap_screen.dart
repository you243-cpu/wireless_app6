import 'dart:async';
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';
import '../widgets/heatmap_2d.dart';
import '../widgets/heatmap_3d.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final heatmapService = HeatmapService();
  final List<String> metrics = [
    'pH',
    'Temperature',
    'Humidity',
    'EC',
    'N',
    'P',
    'K',
    'All'
  ];
  String currentMetric = 'pH';
  DateTime? startTime;
  DateTime? endTime;
  bool is3DView = false;
  bool isLoading = true;
  List<List<double>>? gridData;
  double minValue = 0.0;
  double maxValue = 0.0;
  String? gltfModelPath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final points = await HeatmapService.parseCsvAsset('assets/heatmap_data.csv');
      heatmapService.setPoints(points);

      if (points.isNotEmpty) {
        setState(() {
          startTime = points.first.t;
          endTime = points.last.t;
          isLoading = false;
        });
        _updateGridAndValues();
      }
    } catch (e) {
      // In a real app, you would handle this gracefully (e.g., show an error message).
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateGridAndValues() {
    if (heatmapService.points.isEmpty || startTime == null || endTime == null) {
      setState(() {
        gridData = [];
        minValue = 0;
        maxValue = 0;
      });
      return;
    }

    final newGrid = heatmapService.createGrid(
      metric: currentMetric,
      start: startTime!,
      end: endTime!,
    );

    // Compute min/max values from the grid, ignoring NaN
    final allValues = newGrid.expand((row) => row).where((v) => !v.isNaN).toList();
    if (allValues.isNotEmpty) {
      final min = allValues.reduce((a, b) => a < b ? a : b);
      final max = allValues.reduce((a, b) => a > b ? a : b);

      setState(() {
        gridData = newGrid;
        minValue = min;
        maxValue = max;
      });

      // Handle cases where min and max are the same to avoid division by zero
      if (minValue == maxValue) {
        minValue = minValue - 0.01;
        maxValue = maxValue + 0.01;
      }
    } else {
      setState(() {
        gridData = newGrid;
        minValue = 0;
        maxValue = 0;
      });
    }
  }

  void _onMetricChanged(String? newMetric) {
    if (newMetric != null) {
      setState(() {
        currentMetric = newMetric;
      });
      _updateGridAndValues();
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: startTime ?? DateTime.now(),
        end: endTime ?? DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        startTime = picked.start;
        endTime = picked.end;
      });
      _updateGridAndValues();
    }
  }

  void _toggleView() {
    setState(() {
      is3DView = !is3DView;
    });

    if (is3DView) {
      // In a real app, you would generate the GLTF model here
      // and set the gltfModelPath.
      // For this example, we will just simulate a path.
      gltfModelPath = 'assets/simulated_3d_model.gltf';
    } else {
      gltfModelPath = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap Viewer'),
        backgroundColor: isDark ? Colors.grey[800] : Colors.blue,
        actions: [
          IconButton(
            icon: Icon(is3DView ? Icons.view_agenda : Icons.view_in_ar),
            onPressed: _toggleView,
            tooltip: 'Toggle 2D/3D View',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: currentMetric,
                        items: metrics.map((String metric) {
                          return DropdownMenuItem<String>(
                            value: metric,
                            child: Text(metric),
                          );
                        }).toList(),
                        onChanged: _onMetricChanged,
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _selectDateRange,
                        child: Text(
                          startTime != null && endTime != null
                              ? '${startTime!.year}-${startTime!.month}-${startTime!.day} to ${endTime!.year}-${endTime!.month}-${endTime!.day}'
                              : 'Select Date Range',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: is3DView
                        ? Center(
                            child: Text("3D View is not yet implemented"),
                          )
                        : (gridData != null && gridData!.isNotEmpty)
                            ? Heatmap2D(
                                grid: gridData!,
                                metricLabel: currentMetric,
                                minValue: minValue,
                                maxValue: maxValue,
                              )
                            : const Center(
                                child: Text("No data to display."),
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
