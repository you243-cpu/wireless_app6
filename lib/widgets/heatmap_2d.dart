// lib/widgets/heatmap_2d.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';

/// Simple color map from value -> color
Color valueToColor(double v, double min, double max) {
  if (v.isNaN) return Colors.transparent;
  final t = ((v - min) / (max - min)).clamp(0.0, 1.0);
  if (t < 0.33) {
    final tt = t / 0.33;
    return Color.lerp(Colors.blue, Colors.green, tt)!;
  } else if (t < 0.66) {
    final tt = (t - 0.33) / 0.33;
    return Color.lerp(Colors.green, Colors.yellow, tt)!;
  } else {
    final tt = (t - 0.66) / 0.34;
    return Color.lerp(Colors.yellow, Colors.red, tt)!;
  }
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
    final rows = grid.length;
    final cols = rows > 0 ? grid[0].length : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: cols * cellSize + 60, // space for legend
      height: rows * cellSize,
      child: CustomPaint(
        painter: _HeatmapPainter(
          grid,
          cellSize,
          showGridLines,
          metricLabel,
          isDark,
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<List<double>> grid;
  final double cellSize;
  final bool showGridLines;
  final String metricLabel;
  final bool isDark;

  _HeatmapPainter(
    this.grid,
    this.cellSize,
    this.showGridLines,
    this.metricLabel,
    this.isDark,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (grid.isEmpty) return;
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

    final paint = Paint();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = grid[r][c];
        final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        paint.color = valueToColor(v, minV, maxV);
        canvas.drawRect(rect, paint);

        if (showGridLines) {
          final border = Paint()
            ..color = isDark ? Colors.white24 : Colors.black12
            ..style = PaintingStyle.stroke;
          canvas.drawRect(rect, border);
        }
      }
    }

    // Legend
    const legendWidth = 20.0;
    final legendHeight = rows * cellSize;
    final legendLeft = cols * cellSize + 10;
    final legendTop = 0.0;

    final legendRect = Rect.fromLTWH(legendLeft, legendTop, legendWidth, legendHeight);
    final legendShader = ui.Gradient.linear(
      Offset(legendLeft, legendTop),
      Offset(legendLeft, legendTop + legendHeight),
      [Colors.red, Colors.yellow, Colors.green, Colors.blue].reversed.toList(),
      [0.0, 0.33, 0.66, 1.0],
    );
    final legendPaint = Paint()..shader = legendShader;
    canvas.drawRect(legendRect, legendPaint);

    // Legend border
    final borderPaint = Paint()
      ..color = isDark ? Colors.white54 : Colors.black54
      ..style = PaintingStyle.stroke;
    canvas.drawRect(legendRect, borderPaint);

    // Legend labels
    final textStyle = TextStyle(
      color: isDark ? Colors.white70 : Colors.black,
      fontSize: 12,
    );

    final minText = TextPainter(
      text: TextSpan(text: minV.toStringAsFixed(2), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minText.paint(canvas, Offset(legendLeft + legendWidth + 4, legendHeight - 14));

    final maxText = TextPainter(
      text: TextSpan(text: maxV.toStringAsFixed(2), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxText.paint(canvas, Offset(legendLeft + legendWidth + 4, 0));

    // Metric label
    final tp = TextPainter(
      text: TextSpan(text: metricLabel, style: textStyle.copyWith(fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(legendLeft, legendHeight + 4));
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) {
    return old.grid != grid || old.cellSize != cellSize || old.isDark != isDark;
  }
}
