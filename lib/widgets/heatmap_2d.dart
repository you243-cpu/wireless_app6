import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/heatmap_service.dart'; // Ensure this import path is correct
import 'heatmap_legend.dart';

class Heatmap2D extends StatelessWidget {
  final List<List<double>> grid;
  final double geographicWidthRatio; // Ratio (Delta Lon / Delta Lat) for aspect correction
  final bool showGridLines;
  final String metricLabel;
  final double minValue;
  final double maxValue;
  final List<double>? optimalRangeOverride;

  const Heatmap2D({
    super.key,
    required this.grid,
    // Provide a default of 1.0 (square) for non-geographic or fallback grids
    this.geographicWidthRatio = 1.0,
    this.showGridLines = false,
    required this.metricLabel,
    required this.minValue,
    required this.maxValue,
    this.optimalRangeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    //  DEBUG Check: Ensure min/max are valid before rendering
    if (!minValue.isFinite || !maxValue.isFinite || maxValue < minValue) {
      return Center(child: Text("Invalid data range for rendering. Min: $minValue, Max: $maxValue"));
    }
    
    if (grid.isEmpty || grid[0].isEmpty) {
      return Center(
          child: Text("No data",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
    }
    
    // Compute aspect ratio from grid dimensions so each cell renders square
    final int rows = grid.length;
    final int cols = grid[0].length;
    final double aspectFromGrid = cols > 0 && rows > 0 ? cols / rows : 1.0;


    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Horizontal legend at the top
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: HeatmapLegend(
                    minValue: minValue,
                    maxValue: maxValue,
                    metricLabel: metricLabel,
                    isDark: isDark,
                    axis: Axis.horizontal,
                    thickness: 14,
                    gradientMode: GradientMode.valueBased,
                    optimalRangeOverride: optimalRangeOverride,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center( // Center the constrained heatmap within the available space
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AspectRatio(
                    // Use grid-based aspect so cells are square on screen
                    aspectRatio: aspectFromGrid,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: CustomPaint(
                        painter: _HeatmapPainter(
                            grid, showGridLines, isDark, metricLabel, minValue, maxValue, optimalRangeOverride),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
  final List<double>? optimalRangeOverride;

  _HeatmapPainter(this.grid, this.showGridLines, this.isDark,
      this.metricLabel, this.minValue, this.maxValue, this.optimalRangeOverride);

  @override
  void paint(Canvas canvas, Size size) {
    //  Critical check: Stop painting if the range is invalid
    if (!minValue.isFinite || !maxValue.isFinite || maxValue < minValue) {
      return; 
    }
    
    final rows = grid.length;
    final cols = grid[0].length;
    final paint = Paint()..isAntiAlias = false; // Avoid hairline seams between cells

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cellValue = grid[r][c];
        
        // Ensure you have access to the valueToColor function from heatmap_service.dart
        paint.color = valueToColor(cellValue, minValue, maxValue, metricLabel,
            optimalRangeOverride: optimalRangeOverride);
        
        final double x0 = c * cellWidth;
        final double y0 = r * cellHeight;
        
        // Simplified and safer boundary calculation using fromLTRB
        final double x1 = (c + 1) * cellWidth; 
        final double y1 = (r + 1) * cellHeight;
        
        final rect = Rect.fromLTRB(x0, y0, x1, y1); 
        
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
      old.maxValue != maxValue ||
      old.optimalRangeOverride != optimalRangeOverride;
}

// Render the heatmap to an offscreen image suitable for saving as PNG
Future<ui.Image> renderHeatmapImage({
  required List<List<double>> grid,
  required String metricLabel,
  required double minValue,
  required double maxValue,
  int cellSize = 16,
  bool showGridLines = false,
  List<double>? optimalRangeOverride,
}) async {
  if (grid.isEmpty || grid[0].isEmpty) {
    // Create a tiny placeholder image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(2, 2);
    final painter = _HeatmapPainter(
      [[double.nan]],
      showGridLines,
      false,
      metricLabel,
      minValue,
      maxValue,
      optimalRangeOverride,
    );
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    return picture.toImage(2, 2);
  }

  final rows = grid.length;
  final cols = grid[0].length;
  final width = (cols * cellSize).clamp(1, 8192);
  final height = (rows * cellSize).clamp(1, 8192);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());
  final painter = _HeatmapPainter(
    grid,
    showGridLines,
    false,
    metricLabel,
    minValue,
    maxValue,
    optimalRangeOverride,
  );
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
