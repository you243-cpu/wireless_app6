import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/controls/OrbitControls.dart' as jsm;
import '../services/heatmap_service.dart';

class Heatmap3DGL extends StatefulWidget {
  final List<List<double>> grid;
  final String metricLabel;
  final double minValue;
  final double maxValue;

  const Heatmap3DGL({
    super.key,
    required this.grid,
    required this.metricLabel,
    required this.minValue,
    required this.maxValue,
  });

  @override
  State<Heatmap3DGL> createState() => _Heatmap3DGLState();
}

class _Heatmap3DGLState extends State<Heatmap3DGL> {
  FlutterGlPlugin? _gl;
  three.WebGLRenderer? _renderer;
  three.Scene? _scene;
  three.PerspectiveCamera? _camera;
  jsm.OrbitControls? _controls;
  three.Object3D? _heatmapObject;
  Size _lastSize = Size.zero;
  double _dpr = 1.0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _controls?.dispose();
    _gl?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Heatmap3DGL oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scene != null && (oldWidget.grid != widget.grid ||
        oldWidget.minValue != widget.minValue ||
        oldWidget.maxValue != widget.maxValue ||
        oldWidget.metricLabel != widget.metricLabel)) {
      _rebuildHeatmap();
    }
  }

  Future<void> _initIfNeeded(Size size) async {
    if (_renderer != null && size == _lastSize) return;
    _lastSize = size;
    _dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.0);

    if (_gl == null) {
      _gl = FlutterGlPlugin();
      await _gl!.initialize(options: {
        'antialias': true,
        'alpha': false,
        'width': size.width.toInt(),
        'height': size.height.toInt(),
        'dpr': _dpr,
      });
      await _gl!.prepareContext();
    } else {
      await _gl!.updateSize(width: size.width.toInt(), height: size.height.toInt());
    }

    final three.WebGLRenderer renderer = three.WebGLRenderer({
      'canvas': _gl!.element,
      'antialias': true,
      'alpha': false,
    });
    renderer.setPixelRatio(_dpr);
    renderer.setSize(size.width, size.height, false);
    _renderer = renderer;

    _scene = three.Scene();
    _scene!.background = three.Color.fromHex(0x000000);

    _camera = three.PerspectiveCamera(45, size.width / size.height, 0.1, 1000);
    _camera!.position.setValues(10, 12, 16);

    _controls = jsm.OrbitControls(_camera, _gl!.element);
    _controls!.enableDamping = true;
    _controls!.target.setValues(0, 0, 0);

    // Lights
    final ambient = three.AmbientLight(three.Color.fromHex(0xffffff), 0.8);
    _scene!.add(ambient);
    final dir = three.DirectionalLight(three.Color.fromHex(0xffffff), 0.9);
    dir.position.setValues(10, 20, 10);
    _scene!.add(dir);

    // Ground grid helper
    final gridHelper = three.GridHelper(40, 40);
    _scene!.add(gridHelper);

    _rebuildHeatmap();
  }

  void _rebuildHeatmap() {
    if (_scene == null) return;
    // Remove previous
    if (_heatmapObject != null) {
      _scene!.remove(_heatmapObject!);
      _heatmapObject = null;
    }

    if (widget.grid.isEmpty || widget.grid[0].isEmpty) {
      return;
    }

    final rows = widget.grid.length;
    final cols = widget.grid[0].length;
    final double safeRange = (widget.maxValue - widget.minValue).abs() < 1e-12
        ? 1.0
        : (widget.maxValue - widget.minValue);

    final box = three.BoxGeometry(1, 1, 1);
    final material = three.MeshStandardMaterial({'vertexColors': true});

    three.Object3D heatmapRoot;
    try {
      final count = rows * cols;
      final instanced = three.InstancedMesh(box, material, count);
      int index = 0;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final v = widget.grid[r][c];
          final matrix = three.Matrix4();
          if (!v.isFinite) {
            matrix.setPosition(three.Vector3(c.toDouble(), -1000, r.toDouble()));
            instanced.setMatrixAt(index, matrix);
            instanced.setColorAt(index, three.Color.fromHex(0x000000));
            index++;
            continue;
          }
          final t = ((v - widget.minValue) / safeRange).clamp(0.0, 1.0);
          final height = 0.2 + t * 2.0;
          final flutterColor = valueToColor(v, widget.minValue, widget.maxValue, widget.metricLabel);
          final rgb = flutterColor.value & 0xFFFFFF; // strip alpha
          final threeColor = three.Color.fromHex(rgb);

          matrix.compose(
            three.Vector3(c.toDouble(), height / 2.0, r.toDouble()),
            three.Quaternion(0, 0, 0, 1),
            three.Vector3(0.9, height, 0.9),
          );
          instanced.setMatrixAt(index, matrix);
          instanced.setColorAt(index, threeColor);
          index++;
        }
      }
      instanced.instanceMatrix!.needsUpdate = true;
      if (instanced.instanceColor != null) instanced.instanceColor!.needsUpdate = true;
      heatmapRoot = instanced;
    } catch (_) {
      // Fallback: create individual meshes
      final group = three.Group();
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final v = widget.grid[r][c];
          if (!v.isFinite) continue;
          final t = ((v - widget.minValue) / safeRange).clamp(0.0, 1.0);
          final height = 0.2 + t * 2.0;
          final flutterColor = valueToColor(v, widget.minValue, widget.maxValue, widget.metricLabel);
          final rgb = flutterColor.value & 0xFFFFFF;
          final meshMat = three.MeshStandardMaterial({'color': three.Color.fromHex(rgb)});
          final mesh = three.Mesh(box, meshMat);
          mesh.position.setValues(c.toDouble(), height / 2.0, r.toDouble());
          mesh.scale.setValues(0.9, height, 0.9);
          group.add(mesh);
        }
      }
      heatmapRoot = group;
    }

    heatmapRoot.position.setValues(-(cols / 2), 0, -(rows / 2));
    _scene!.add(heatmapRoot);
    _heatmapObject = heatmapRoot;
  }

  void _render() {
    if (_disposed || _renderer == null || _scene == null || _camera == null) return;
    _controls?.update();
    _renderer!.render(_scene!, _camera!);
    _gl?.gl.flush();
  }

  void _animate() {
    if (!mounted || _disposed) return;
    _render();
    Future.microtask(_animate);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        scheduleMicrotask(() async {
          await _initIfNeeded(size);
          if (mounted) _animate();
        });

        if (_gl == null || _gl!.textureId == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Texture(textureId: _gl!.textureId!);
      },
    );
  }
}
