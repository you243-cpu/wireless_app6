import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/heatmap_service.dart'; // Ensure this import path is correct

class Heatmap2D extends StatelessWidget {
  final List<List<double>> grid;
  final double geographicWidthRatio; // Ratio (Delta Lon / Delta Lat) for aspect correction
  final bool showGridLines;
  final String metricLabel;
  final double minValue;
  final double maxValue;
  final List<double>? optimalRangeOverride;
  final bool showIndices;
  final void Function(int row, int col)? onCellTap;
  final int? highlightRow;
  final int? highlightCol;

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
    this.showIndices = false,
    this.onCellTap,
    this.highlightRow,
    this.highlightCol,
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
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AspectRatio(
              aspectRatio: aspectFromGrid,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: onCellTap == null
                    ? null
                    : (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final Size size = box.size;
                        final int rows = grid.length;
                        final int cols = grid[0].length;
                        // Reserve margins for axes when indices are shown
                        final double leftMargin = showIndices ? 28.0 : 0.0;
                        final double topMargin = showIndices ? 18.0 : 0.0;
                        final double rightMargin = showIndices ? 6.0 : 0.0;
                        final double bottomMargin = showIndices ? 6.0 : 0.0;
                        final double drawWidth = size.width - leftMargin - rightMargin;
                        final double drawHeight = size.height - topMargin - bottomMargin;
                        final double cellWidth = drawWidth / cols;
                        final double cellHeight = drawHeight / rows;
                        final Offset p = details.localPosition;
                        if (p.dx < leftMargin || p.dy < topMargin ||
                            p.dx > leftMargin + drawWidth || p.dy > topMargin + drawHeight) {
                          onCellTap?.call(-1, -1); // deselect
                          return;
                        }
                        final int c = ((p.dx - leftMargin) / cellWidth).floor().clamp(0, cols - 1);
                        final int r = ((p.dy - topMargin) / cellHeight).floor().clamp(0, rows - 1);
                        onCellTap?.call(r, c);
                      },
                child: CustomPaint(
                  painter: _HeatmapPainter(
                    grid,
                    showGridLines,
                    isDark,
                    metricLabel,
                    minValue,
                    maxValue,
                    optimalRangeOverride,
                    showIndices,
                    highlightRow,
                    highlightCol,
                  ),
                ),
              ),
            );
          },
        ),
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
  final bool showIndices;
  final int? highlightRow;
  final int? highlightCol;

  _HeatmapPainter(this.grid, this.showGridLines, this.isDark,
      this.metricLabel, this.minValue, this.maxValue, this.optimalRangeOverride, this.showIndices, this.highlightRow, this.highlightCol);

  @override
  void paint(Canvas canvas, Size size) {
    //  Critical check: Stop painting if the range is invalid
    if (!minValue.isFinite || !maxValue.isFinite || maxValue < minValue) {
      return; 
    }
    
    final rows = grid.length;
    final cols = grid[0].length;
    final paint = Paint()..isAntiAlias = false; // Avoid hairline seams between cells
    // Margins for axes when indices enabled
    final double leftMargin = showIndices ? 28.0 : 0.0;
    final double topMargin = showIndices ? 18.0 : 0.0;
    final double rightMargin = showIndices ? 6.0 : 0.0;
    final double bottomMargin = showIndices ? 6.0 : 0.0;
    final double drawWidth = size.width - leftMargin - rightMargin;
    final double drawHeight = size.height - topMargin - bottomMargin;
    final cellWidth = drawWidth / cols;
    final cellHeight = drawHeight / rows;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cellValue = grid[r][c];
        
        // Ensure you have access to the valueToColor function from heatmap_service.dart
        paint.color = valueToColor(cellValue, minValue, maxValue, metricLabel,
            optimalRangeOverride: optimalRangeOverride);
        
        final double x0 = leftMargin + c * cellWidth;
        final double y0 = topMargin + r * cellHeight;
        
        // Simplified and safer boundary calculation using fromLTRB
        final double x1 = (c + 1) * cellWidth; 
        final double y1 = (r + 1) * cellHeight;
        
        final rect = Rect.fromLTRB(x0, y0, x1, y1); 
        
        canvas.drawRect(rect, paint);

        if (showGridLines) {
          final border = Paint()
            ..color = Colors.white.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8;
          canvas.drawRect(rect, border);
        }
      }
    }

    // Draw highlight rectangle around selected cell
    if (highlightRow != null && highlightCol != null &&
        highlightRow! >= 0 && highlightRow! < rows &&
        highlightCol! >= 0 && highlightCol! < cols) {
      final double hx0 = leftMargin + highlightCol! * cellWidth;
      final double hy0 = topMargin + highlightRow! * cellHeight;
      final rect = Rect.fromLTWH(hx0, hy0, cellWidth, cellHeight);
      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.yellowAccent;
      canvas.drawRect(rect, highlightPaint);
    }

    // Draw axis indices along top (columns) and left (rows)
    if (showIndices) {
      final textStyle = TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 10,
      );
      final bgPaint = Paint()
        ..color = (isDark ? Colors.black : Colors.white).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      // Columns labels above top edge
      for (int c = 0; c < cols; c++) {
        final tp = TextPainter(
          text: TextSpan(text: c.toString(), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = leftMargin + c * cellWidth + cellWidth * 0.5 - tp.width / 2;
        final double ty = topMargin - tp.height - 2;
        final rect = Rect.fromLTWH(dx - 2, ty - 1, tp.width + 4, tp.height + 2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), bgPaint);
        tp.paint(canvas, Offset(dx, ty));
      }
      // Rows labels left of left edge
      for (int r = 0; r < rows; r++) {
        final tp = TextPainter(
          text: TextSpan(text: r.toString(), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final double dy = topMargin + r * cellHeight + cellHeight * 0.5 - tp.height / 2;
        final double lx = leftMargin - tp.width - 4;
        final rect = Rect.fromLTWH(lx - 2, dy - 1, tp.width + 4, tp.height + 2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), bgPaint);
        tp.paint(canvas, Offset(lx, dy));
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
      false,
      null,
      null,
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
    false,
    null,
    null,
  );
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
