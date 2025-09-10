import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import '../services/heatmap_service.dart';
import 'heatmap_legend.dart';
import 'heatmap_2d.dart';

Future<Uint8List> renderGridToPngBytes(List<List<double>> grid, {int pixelPerCell = 8}) async {
  final rows = grid.length;
  final cols = rows > 0 ? grid[0].length : 0;
  final width = (cols * pixelPerCell).clamp(1, 4096).toInt();
  final height = (rows * pixelPerCell).clamp(1, 4096).toInt();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  final cellW = width / cols;
  final cellH = height / rows;

  double minV = double.infinity, maxV = -double.infinity;
  for (var r = 0; r < rows; r++) for (var c = 0; c < cols; c++) {
    final v = grid[r][c];
    if (!v.isNaN) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
  }
  if (minV == double.infinity) { minV = 0; maxV = 1; }

  final paint = Paint();
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      paint.color = valueToColor(grid[r][c], minV, maxV);
      canvas.drawRect(Rect.fromLTWH(c*cellW, r*cellH, cellW, cellH), paint);
    }
  }

  final img = await recorder.endRecording().toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

class Heatmap3DViewer extends StatefulWidget {
  final List<List<double>> grid;
  final double planeSize;
  final VoidCallback? onReset;
  final String metricLabel;

  const Heatmap3DViewer({
    super.key,
    required this.grid,
    this.planeSize = 4.0,
    this.onReset,
    this.metricLabel = "value",
  });

  @override
  State<Heatmap3DViewer> createState() => _Heatmap3DViewerState();
}

class _Heatmap3DViewerState extends State<Heatmap3DViewer> {
  Object? planeObj;
  late Scene _scene;
  Uint8List? _imageBytes;
  double _minValue = 0;
  double _maxValue = 1;

  @override
  void initState() {
    super.initState();
    _generateTexture();
  }

  Future<void> _generateTexture() async {
    if (widget.grid.isEmpty) return;

    _minValue = widget.grid.expand((r) => r).where((v) => !v.isNaN).fold<double>(double.infinity, (p,c)=> c<p?c:p);
    _maxValue = widget.grid.expand((r) => r).where((v) => !v.isNaN).fold<double>(-double.infinity, (p,c)=> c>p?c:p);

    final bytes = await renderGridToPngBytes(widget.grid, pixelPerCell: 8);
    setState(() => _imageBytes = bytes);
    planeObj = Object(
      name: 'plane',
      scale: Vector3(widget.planeSize, 1, widget.planeSize),
      rotation: Vector3(-90,0,0),
      position: Vector3(0,0,0),
      fileName: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_imageBytes == null) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // 2D preview + legend
              Expanded(
                child: Container(
                  color: isDark ? Colors.black : Colors.white,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Image.memory(_imageBytes!),
                        ),
                      ),
                      SizedBox(
                        height: 60,
                        child: HeatmapLegend(
                          minValue: _minValue,
                          maxValue: _maxValue,
                          metricLabel: widget.metricLabel,
                          isDark: isDark,
                          axis: Axis.horizontal,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              // 3D viewer
              Expanded(
                child: Container(
                  color: isDark ? Colors.black : Colors.white,
                  child: Cube(
                    onSceneCreated: (Scene scene) {
                      _scene = scene;
                      scene.camera.zoom = 10;
                      if (planeObj != null) scene.world.add(planeObj!);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.onReset,
                icon: const Icon(Icons.reset_tv),
                label: const Text("Reset view"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Use the 2D preview or the 3D pane (tap/drag to rotate).",
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
