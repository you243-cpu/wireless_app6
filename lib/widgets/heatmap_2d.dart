import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/heatmap_service.dart';
import 'heatmap_legend.dart';

class Heatmap2D extends StatelessWidget {
  final List<List<double>> grid;
  final double cellSize;
  final bool showGridLines;
  final String metricLabel;
  final double minValue;
  final double maxValue;

  const Heatmap2D({
    super.key,
    required this.grid,
    this.cellSize = 10,
    this.showGridLines = false,
    required this.metricLabel,
    required this.minValue,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (grid.isEmpty) {
      return Center(
          child: Text("No data",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }

    final rows = grid.length;
    final cols = grid[0].length;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: cols * cellSize,
              height: rows * cellSize,
              child: CustomPaint(
                painter: _HeatmapPainter(
                    grid, cellSize, showGridLines, isDark, metricLabel, minValue, maxValue),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: rows * cellSize,
          width: 60,
          child: HeatmapLegend(
            minValue: minValue,
            maxValue: maxValue,
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
  final String metricLabel;
  final double minValue;
  final double maxValue;

  _HeatmapPainter(this.grid, this.cellSize, this.showGridLines, this.isDark,
      this.metricLabel, this.minValue, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    final cols = grid[0].length;
    final paint = Paint();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        paint.color = valueToColor(grid[r][c], minValue, maxValue, metricLabel);
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

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.grid != grid ||
      old.cellSize != cellSize ||
      old.isDark != isDark ||
      old.metricLabel != metricLabel ||
      old.minValue != minValue ||
      old.maxValue != maxValue;
}
