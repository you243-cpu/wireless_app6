// lib/screens/heatmap_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/heatmap_service.dart';
import '../widgets/heatmap_2d.dart';
import '../widgets/heatmap_3d.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    // set default range if you later load data
  }

  Future<void> _loadCsvFromPicker() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['csv']
    );
    if (res == null) return;
    final path = res.files.single.path!;
    final content = await File(path).readAsString();
    final pts = HeatmapService.parseCsvString(content);
    _svc.setPoints(pts);

    if (pts.isNotEmpty) {
      final minT = pts.map((p) => p.t).reduce((a,b) => a.isBefore(b) ? a : b);
      final maxT = pts.map((p) => p.t).reduce((a,b) => a.isAfter(b) ? a : b);
      setState(() {
        _range = DateTimeRange(start: minT, end: maxT);
      });
      _computeGrid();
    }
  }

  void _computeGrid() {
    if (_range == null) return;
    final rowsColsGrid = _svc.createGrid(
      metric: _metric,
      start: _range!.start,
      end: _range!.end,
      cols: cols,
      rows: rows,
    );
    setState(() {
      _grid = rowsColsGrid;
    });
  }

  void _setMetric(String metric) {
    setState(() {
      _metric = metric;
      _computeGrid();
    });
  }

  void _pickRange() async {
    if (_svc.points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Load CSV first"))
      );
      return;
    }
    final minT = _svc.points.map((p) => p.t).reduce((a,b) => a.isBefore(b) ? a : b);
    final maxT = _svc.points.map((p) => p.t).reduce((a,b) => a.isAfter(b) ? a : b);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: minT,
      lastDate: maxT,
      initialDateRange: _range ?? DateTimeRange(start: minT, end: maxT),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
      });
      _computeGrid();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Full set of supported metrics
    final metrics = ['pH', 'Temperature', 'Humidity', 'EC', 'N', 'P', 'K'];

    return Scaffold(
      appBar: AppBar(title: const Text("Heatmap Viewer")),
      body: Column(
        children: [
          // loader + controls
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8, 
              crossAxisAlignment: WrapCrossAlignment.center, 
              children: [
                ElevatedButton.icon(
                  onPressed: _loadCsvFromPicker, 
                  icon: const Icon(Icons.upload_file), 
                  label: const Text("Load CSV")
                ),
                const Text("Metric:"),
                DropdownButton<String>(
                  value: _metric, 
                  items: metrics.map((m) => DropdownMenuItem(
                    value: m, 
                    child: Text(m)
                  )).toList(), 
                  onChanged: (v) { 
                    if (v!=null) _setMetric(v); 
                  }
                ),
                ElevatedButton(
                  onPressed: _pickRange, 
                  child: const Text("Pick Date Range")
                ),
                const Text("Cols:"),
                SizedBox(
                  width: 80, 
                  child: TextFormField(
                    initialValue: cols.toString(), 
                    keyboardType: TextInputType.number, 
                    onChanged: (s){ 
                      final v=int.tryParse(s); 
                      if (v!=null) cols=v; 
                    }
                  )
                ),
                const Text("Rows:"),
                SizedBox(
                  width: 80, 
                  child: TextFormField(
                    initialValue: rows.toString(), 
                    keyboardType: TextInputType.number, 
                    onChanged: (s){ 
                      final v=int.tryParse(s); 
                      if (v!=null) rows=v; 
                    }
                  )
                ),
                ElevatedButton(
                  onPressed: _computeGrid, 
                  child: const Text("Rebuild Grid")
                ),
                ElevatedButton(
                  onPressed: () => setState(()=>_show3D=!_show3D), 
                  child: Text(_show3D ? "Show 2D" : "Show 3D")
                ),
              ]
            ),
          ),

          Expanded(
            child: _grid.isEmpty
              ? const Center(child: Text("No grid yet — load CSV and pick range"))
              : _show3D
                ? Heatmap3DViewer(
                    grid: _grid, 
                    onReset: () {
                      // TODO: implement camera reset in Heatmap3DViewer
                    }
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Heatmap2D(
                        grid: _grid, 
                        cellSize: 8, 
                        showGridLines: false, 
                        metricLabel: _metric
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
