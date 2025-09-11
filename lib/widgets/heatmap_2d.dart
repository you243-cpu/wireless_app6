import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/heatmap_service.dart';
import 'heatmap_legend.dart';

class Heatmap2D extends StatelessWidget {
  final List<List<double>> grid;
  final bool showGridLines;
  final String metricLabel;
  final double minValue;
  final double maxValue;

  const Heatmap2D({
    super.key,
    required this.grid,
    this.showGridLines = false,
    required this.metricLabel,
    required this.minValue,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (grid.isEmpty || grid[0].isEmpty) {
      return Center(
          child: Text("No data",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }

    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: CustomPaint(
                  painter: _HeatmapPainter(
                    grid, showGridLines, isDark, metricLabel, minValue, maxValue),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.8, // Adjust height to be proportional
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
  final bool showGridLines;
  final bool isDark;
  final String metricLabel;
  final double minValue;
  final double maxValue;

  _HeatmapPainter(this.grid, this.showGridLines, this.isDark,
      this.metricLabel, this.minValue, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    final cols = grid[0].length;
    final paint = Paint();

    // Calculate cell size dynamically
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        paint.color = valueToColor(grid[r][c], minValue, maxValue, metricLabel);
        final rect = Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth, cellHeight);
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
      old.isDark != isDark ||
      old.metricLabel != metricLabel ||
      old.minValue != minValue ||
      old.maxValue != maxValue;
}
