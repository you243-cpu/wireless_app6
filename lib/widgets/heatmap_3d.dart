// lib/widgets/heatmap_3d.dart
import 'package:flutter/material.dart' hide Material;
import 'package:flutter_cube/flutter_cube.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' as vector_math;
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
    if (oldWidget.grid != widget.grid || oldWidget.metricLabel != widget.metricLabel) {
      _create3dObject();
    }
  }

  void _create3dObject() {
    if (widget.grid.isEmpty) {
      heatmapObj = null;
      if (_scene != null) {
        // Clear all objects from the scene if the grid is empty
        _scene!.world.removeAll();
      }
      return;
    }
    
    final rows = widget.grid.length;
    final cols = widget.grid[0].length;
    final rootObj = Object(
      name: 'heatmap_root',
      rotation: vector_math.Vector3(widget.controller.rotationX, widget.controller.rotationY, 0),
    );

    final cellScaleX = widget.planeSize / cols;
    final cellScaleZ = widget.planeSize / rows;
    const minHeight = 0.1;
    const maxHeight = 2.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final value = widget.grid[r][c];
        if (value.isNaN) continue;

        final normalizedValue =
            ((value - widget.minValue) / (widget.maxValue - widget.minValue)).clamp(0.0, 1.0);
        final height = normalizedValue * maxHeight + minHeight;

        final cube = Object(
          name: 'cell_$r\_$c',
          fileName: 'assets/models/cube.obj',
          position: vector_math.Vector3(
              (c - cols / 2 + 0.5) * cellScaleX, height / 2, (r - rows / 2 + 0.5) * cellScaleZ),
          scale: vector_math.Vector3(cellScaleX, height, cellScaleZ),
        );
        // The Material property has been moved to a separate addMaterial function
        cube.addMaterial(
            Material(
                color: valueToColor(value, widget.minValue, widget.maxValue, widget.metricLabel),
            ),
        );
        rootObj.add(cube);
      }
    }
    
    // Check if the scene is initialized before trying to modify it
    if (_scene != null) {
      _scene!.world.removeAll();
      _scene!.world.add(rootObj);
    }
    heatmapObj = rootObj;
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

    if (heatmapObj == null && widget.grid.isNotEmpty) {
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
                  scene.world.add(Object(fileName: 'assets/models/plane.obj'));
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
