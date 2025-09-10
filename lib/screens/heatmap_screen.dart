// lib/screens/heatmap_screen.dart
import 'package:flutter/material.dart';
import '../widgets/heatmap_2d.dart';
import '../widgets/heatmap_3d.dart';
import '../main.dart';
import '../services/heatmap_service.dart';

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
  String _metric = 'pH';
  DateTimeRange? _range;
  int cols = 40, rows = 40;
  List<List<double>> _grid = [];
  bool _show3D = false;

  // 3D camera controller
  late Heatmap3DController _cameraController;

  @override
  void initState() {
    super.initState();
    _cameraController = Heatmap3DController();
    _computeGrid();
  }

  void _computeGrid() {
    if (widget.timestamps.isEmpty) return;

    _range ??= DateTimeRange(start: widget.timestamps.first, end: widget.timestamps.last);

    final dataGrid = _svc.createGrid(
      metric: _metric,
      start: _range!.start,
      end: _range!.end,
      cols: cols,
      rows: rows,
      readings: _getMetricData(_metric),
    );

    setState(() {
      _grid = dataGrid;
    });
  }

  List<double> _getMetricData(String metric) {
    switch (metric) {
      case 'pH':
        return widget.pHReadings;
      case 'Temperature':
        return widget.temperatureReadings;
      case 'Humidity':
        return widget.humidityReadings;
      case 'EC':
        return widget.ecReadings;
      case 'N':
        return widget.nReadings;
      case 'P':
        return widget.pReadings;
      case 'K':
        return widget.kReadings;
      default:
        return widget.pHReadings;
    }
  }

  void _setMetric(String metric) {
    setState(() {
      _metric = metric;
      _computeGrid();
    });
  }

  void _pickRange() async {
    if (widget.timestamps.isEmpty) return;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: widget.timestamps.first,
      lastDate: widget.timestamps.last,
      initialDateRange: _range,
    );

    if (picked != null) {
      setState(() {
        _range = picked;
      });
      _computeGrid();
    }
  }

  void _resetCamera() {
    _cameraController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ['pH', 'Temperature', 'Humidity', 'EC', 'N', 'P', 'K'];
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
          // Controls
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text("Metric:"),
                DropdownButton<String>(
                  value: _metric,
                  items: metrics
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _setMetric(v);
                  },
                ),
                ElevatedButton(onPressed: _pickRange, child: const Text("Pick Date Range")),
                const Text("Cols:"),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: cols.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (s) {
                      final v = int.tryParse(s);
                      if (v != null) cols = v;
                    },
                  ),
                ),
                const Text("Rows:"),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: rows.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (s) {
                      final v = int.tryParse(s);
                      if (v != null) rows = v;
                    },
                  ),
                ),
                ElevatedButton(onPressed: _computeGrid, child: const Text("Rebuild Grid")),
                ElevatedButton(
                  onPressed: () => setState(() => _show3D = !_show3D),
                  child: Text(_show3D ? "Show 2D" : "Show 3D"),
                ),
                if (_show3D)
                  ElevatedButton(
                    onPressed: _resetCamera,
                    child: const Text("Reset Camera"),
                  ),
              ],
            ),
          ),
          // Grid view
          Expanded(
            child: _grid.isEmpty
                ? const Center(child: Text("No grid yet — pick metric and date range"))
                : _show3D
                    ? Heatmap3DViewer(
                        grid: _grid,
                        controller: _cameraController,
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
