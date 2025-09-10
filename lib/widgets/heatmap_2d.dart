import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';
import 'heatmap_legend.dart';

Color valueToColor(double v, double min, double max) {
  if (v.isNaN) return Colors.transparent;
  final t = ((v - min) / (max - min)).clamp(0.0, 1.0);
  if (t < 0.33) return Color.lerp(Colors.blue, Colors.green, t / 0.33)!;
  if (t < 0.66) return Color.lerp(Colors.green, Colors.yellow, (t - 0.33) / 0.33)!;
  return Color.lerp(Colors.yellow, Colors.red, (t - 0.66) / 0.34)!;
}

class Heatmap2D extends StatelessWidget {
  final List<List<double>> grid;
  final double cellSize;
  final bool showGridLines;
  final String metricLabel;

  const Heatmap2D({
    super.key,
    required this.grid,
    this.cellSize = 10,
    this.showGridLines = false,
    this.metricLabel = "value",
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (grid.isEmpty) {
      return Center(child: Text("No data", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }

    final rows = grid.length;
    final cols = grid[0].length;

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

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            width: cols * cellSize,
            height: rows * cellSize,
            child: CustomPaint(
              painter: _HeatmapPainter(grid, cellSize, showGridLines, isDark),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: rows * cellSize,
          width: 60,
          child: HeatmapLegend(
            minValue: minV,
            maxValue: maxV,
            metricLabel: metricLabel,
            isDark: isDark,
            axis: Axis.vertical,
          ),
        )
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<List<double>> grid;
  final double cellSize;
  final bool showGridLines;
  final bool isDark;

  _HeatmapPainter(this.grid, this.cellSize, this.showGridLines, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    final cols = grid[0].length;
    final paint = Paint();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        paint.color = valueToColor(grid[r][c], _minVal(), _maxVal());
        final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        canvas.drawRect(rect, paint);

        if (showGridLines) {
          final border = Paint()
            ..color = isDark ? Colors.white24 : Colors.black12
            ..style = PaintingStyle.stroke;
          canvas.drawRect(rect, border);
        }
      }
    }
  }

  double _minVal() {
    double minV = double.infinity;
    for (var r in grid) for (var c in r) if (!c.isNaN && c < minV) minV = c;
    return minV == double.infinity ? 0 : minV;
  }

  double _maxVal() {
    double maxV = -double.infinity;
    for (var r in grid) for (var c in r) if (!c.isNaN && c > maxV) maxV = c;
    return maxV == -double.infinity ? 1 : maxV;
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) => old.grid != grid || old.cellSize != cellSize || old.isDark != isDark;
}
