// lib/widgets/heatmap_3d.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import '../services/heatmap_service.dart';
import 'heatmap_2d.dart';

/// Utility: render the 2D grid to an ui.Image (bitmap) then return bytes PNG
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
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final v = grid[r][c];
      if (!v.isNaN) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
  }
  if (minV == double.infinity) {
    minV = 0;
    maxV = 1;
  }

  final paint = Paint();
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      paint.color = valueToColor(grid[r][c], minV, maxV);
      final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
      canvas.drawRect(rect, paint);
    }
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 3D viewer widget using flutter_cube; displays the generated heatmap as plane texture.
class Heatmap3DViewer extends StatefulWidget {
  final List<List<double>> grid;
  final double planeSize; // physical size of plane in 3D units
  final VoidCallback? onReset;

  const Heatmap3DViewer({
    super.key,
    required this.grid,
    this.planeSize = 4.0,
    this.onReset,
  });

  @override
  State<Heatmap3DViewer> createState() => _Heatmap3DViewerState();
}

class _Heatmap3DViewerState extends State<Heatmap3DViewer> {
  Object? planeObj;
  late Scene _scene;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _generateTexture();
  }

  Future<void> _generateTexture() async {
    final bytes = await renderGridToPngBytes(widget.grid, pixelPerCell: 8);
    setState(() => _imageBytes = bytes);
    _buildPlane(bytes);
  }

  void _buildPlane(Uint8List bytes) {
    planeObj = Object(
      name: 'plane',
      scale: Vector3(widget.planeSize, 1, widget.planeSize),
      rotation: Vector3(-90, 0, 0),
      position: Vector3(0, 0, 0),
      fileName: null,
    );
    if (_scene != null) {
      try {
        _scene.world.add(planeObj!);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_imageBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // 2D preview
              Expanded(
                child: Container(
                  color: isDark ? Colors.black : Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Image.memory(_imageBytes!),
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
                      if (planeObj != null) {
                        scene.world.add(planeObj!);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // Reset + instructions
        Padding(
          padding: const EdgeInsets.all(8.0),
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
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
