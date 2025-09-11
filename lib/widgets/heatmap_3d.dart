import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import '../services/heatmap_service.dart';
import 'heatmap_legend.dart';

/// Controller for camera rotation & zoom
class Heatmap3DController {
  double rotationX = -90;
  double rotationY = 0;
  double zoom = 10.0;

  void reset() {
    rotationX = -90;
    rotationY = 0;
    zoom = 10.0;
  }
}

class Heatmap3DViewer extends StatefulWidget {
  final List<List<double>> grid;
  final double planeSize;
  final Heatmap3DController controller;
  final String metricLabel;
  final double minValue;
  final double maxValue;

  const Heatmap3DViewer({
    super.key,
    required this.grid,
    required this.controller,
    this.planeSize = 4.0,
    required this.metricLabel,
    required this.minValue,
    required this.maxValue,
  });

  @override
  State<Heatmap3DViewer> createState() => _Heatmap3DViewerState();
}

class _Heatmap3DViewerState extends State<Heatmap3DViewer> {
  Object? heatmapObj;
  Scene? _scene;
  Offset? _lastDrag;
  double? _lastScale;

  @override
  void initState() {
    super.initState();
    _create3dObject();
  }

  @override
  void didUpdateWidget(covariant Heatmap3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-create the 3D object if the grid or metric changes
    if (oldWidget.grid != widget.grid || oldWidget.metricLabel != widget.metricLabel) {
      _create3dObject();
    }
  }

  void _create3dObject() {
    if (widget.grid.isEmpty) return;
    
    final rows = widget.grid.length;
    final cols = widget.grid[0].length;
    final rootObj = Object(
      name: 'heatmap_root',
      rotation: Vector3(widget.controller.rotationX, widget.controller.rotationY, 0),
    );

    final cellScaleX = widget.planeSize / cols;
    final cellScaleZ = widget.planeSize / rows;
    final minHeight = 0.1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final value = widget.grid[r][c];
        if (value.isNaN) continue;

        // Normalize value to a height, clamped to a reasonable range
        final normalizedValue =
            ((value - widget.minValue) / (widget.maxValue - widget.minValue)).clamp(0.0, 1.0);
        final height = normalizedValue * widget.planeSize * 0.5 + minHeight;

        final cube = Object(
          name: 'cell_$r\_$c',
          fileName: 'assets/models/cube.obj', // Ensure you have a simple cube model in assets/models/
          position: Vector3(
              (c - cols / 2 + 0.5) * cellScaleX, height / 2, (r - rows / 2 + 0.5) * cellScaleZ),
          scale: Vector3(cellScaleX, height, cellScaleZ),
          materials: [
            Material(
              diffuse: valueToColor(value, widget.minValue, widget.maxValue, widget.metricLabel),
            )
          ],
        );
        rootObj.add(cube);
      }
    }
    setState(() {
      heatmapObj = rootObj;
      if (_scene != null) {
        _scene!.world.removeAll();
        _scene!.world.add(heatmapObj!);
      }
    });
  }

  void _applyController() {
    if (heatmapObj != null && _scene != null) {
      heatmapObj!.rotation.setValues(widget.controller.rotationX, widget.controller.rotationY, 0);
      _scene!.camera.zoom = widget.controller.zoom;
      _scene!.update();
    }
  }

  void _resetCamera() {
    widget.controller.reset();
    _applyController();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (heatmapObj == null) {
      _create3dObject();
    }

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onPanStart: (details) => _lastDrag = details.localPosition,
            onPanUpdate: (details) {
              if (_lastDrag == null) return;
              final dx = details.localPosition.dx - _lastDrag!.dx;
              final dy = details.localPosition.dy - _lastDrag!.dy;
              _lastDrag = details.localPosition;

              setState(() {
                widget.controller.rotationY += dx * 0.5;
                widget.controller.rotationX += dy * 0.5;
                _applyController();
              });
            },
            onPanEnd: (_) => _lastDrag = null,
            onScaleStart: (details) => _lastScale = widget.controller.zoom,
            onScaleUpdate: (details) {
              if (_lastScale == null) return;
              setState(() {
                widget.controller.zoom =
                    (_lastScale! / details.scale).clamp(2.0, 50.0);
                _applyController();
              });
            },
            child: Container(
              color: isDark ? Colors.black : Colors.white,
              child: Cube(
                onSceneCreated: (scene) {
                  _scene = scene;
                  scene.camera.zoom = widget.controller.zoom;
                  scene.world.add(Object(fileName: 'assets/models/plane.obj')); // Optional ground plane
                  if (heatmapObj != null) scene.world.add(heatmapObj!);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
