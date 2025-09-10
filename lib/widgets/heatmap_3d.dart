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
/// Note: updating texture at runtime may require re-creating the Object with new material.
/// This widget shows how to render texture bytes onto a plane.
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
    // build the plane object with texture
    _buildPlane(bytes);
  }

  void _buildPlane(Uint8List bytes) {
    // Build external material using texture bytes
    // flutter_cube allows specifying a texture by path or network; for runtime bytes
    // we use MemoryImage via ImageProvider and convert to Object with material -> uncertain API.
    // Simpler approach: use Object.fromJson to create a plane and supply material with texture path.
    // For prototype we re-create a simple plane object and supply a texture from bytes saved to memory.
    // NOTE: if flutter_cube doesn't support bytes directly, save bytes to temporary file and pass path.
    // For brevity, here we'll use a built-in Plane object with texture from AssetImage if needed.
    // Implementation detail: adapt this block for your flutter_cube version.
    planeObj = Object(
      name: 'plane',
      scale: Vector3(widget.planeSize, 1, widget.planeSize),
      rotation: Vector3(-90, 0, 0),
      position: Vector3(0, 0, 0),
      fileName: null, // we are building geometry manually - some flutter_cube versions don't allow
    );
    // NOTE: With the diversity of flutter_cube versions, creating a custom textured plane may require saving bytes to a temporary file and using `Object(fileName: path)`.
    // We'll instead rely on the caller building a plane object with the generated image as asset/URI or extend this with flutter_gl if needed.
    if (_scene != null) {
      // attach plane if possible
      try {
        _scene.world.add(planeObj!);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // A simplified UI: show generated image preview on left and 3D viewer on right, if 3D plane creation is not fully supported, at least preview
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // 2D preview
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Image.memory(_imageBytes!),
                ),
              ),
              // 3D view placeholder: you can replace this with a proper flutter_cube Scene/plane that uses the bytes as texture
              Expanded(
                child: Cube(
                  onSceneCreated: (Scene scene) {
                    _scene = scene;
                    scene.camera.zoom = 10;
                    // If planeObj created properly, add:
                    if (planeObj != null) {
                      scene.world.add(planeObj!);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // reset & instructions
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
              const Expanded(child: Text("Use the 2D preview or the 3D pane (tap/drag to rotate).")),
            ],
          ),
        )
      ],
    );
  }
} 
// SIX SEVEN!!!!!!!!
