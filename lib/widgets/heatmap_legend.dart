import 'package:flutter/material.dart';
// NOTE: Since the value-based stop logic was removed, 
// the service import is technically not needed for the legend widget itself, 
// but is kept here for completeness with the rest of your system.
import '../services/heatmap_service.dart'; 

class HeatmapLegend extends StatelessWidget {
  final double minValue;
  final double maxValue;
  final String metricLabel;
  final bool isDark;
  final Axis axis;
  final double thickness;

  const HeatmapLegend({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.metricLabel,
    this.isDark = false,
    this.axis = Axis.vertical,
    this.thickness = 20,
  });

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------------------------
    // FIXED SYMMETRICAL GRADIENT LOGIC (To ensure full color range is visible)
    // Blue (0.0) -> Green (0.3) | Green (0.7) -> Red (1.0)
    // This provides a consistent, centered 40% Green band.
    const double greenStart = 0.3;
    const double greenEnd = 0.7;

    final stops = [
      0.0,        // Start of Blue
      greenStart, // Start of Green (Optimal Min)
      greenEnd,   // End of Green (Optimal Max)
      1.0         // End of Red
    ];

    final gradientColors = [
      Colors.blue,
      Colors.green,
      Colors.green,
      Colors.red,
    ];
    // ----------------------------------------------------------------------

    if (axis == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align title and bar/labels
        children: [
          // FIX: Added maxLines and overflow to prevent the label from wrapping/overflowing
          Text(
            metricLabel,
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          // NOTE: This Expanded will correctly fill the height provided by the parent
          // SizedBox(height: double.infinity) in Heatmap2D.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: thickness,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // Increase from bottom (min/blue) to top (max/red)
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: gradientColors,
                      stops: stops,
                    ),
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black54,
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Labels aligned to the bar: top = max, bottom = min
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maxValue.toStringAsFixed(2),
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                    ),
                    Text(
                      minValue.toStringAsFixed(2),
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Horizontal axis implementation (using the same fixed gradient stops)
      return Row(
        children: [
          Text(
            minValue.toStringAsFixed(2),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: thickness,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradientColors,
                  stops: stops,
                ),
                border: Border.all(
                  color: isDark ? Colors.white54 : Colors.black54,
                  width: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // FIX: Applying the ellipsis overflow property if the text wraps too much
          Text(
            maxValue.toStringAsFixed(2),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
          ),
        ],
      );
    }
  }
}
