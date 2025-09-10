// lib/widgets/heatmap_legend.dart
import 'package:flutter/material.dart';

class HeatmapLegend extends StatelessWidget {
  final double minValue;
  final double maxValue;
  final String metricLabel;
  final bool isDark;
  final Axis axis; // vertical or horizontal
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
    final gradientColors = [Colors.blue, Colors.green, Colors.yellow, Colors.red];

    return axis == Axis.vertical
        ? Column(
            children: [
              Text(
                metricLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Container(
                  width: thickness,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors.reversed.toList(),
                      stops: [0.0, 0.33, 0.66, 1.0],
                    ),
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black54,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    minValue.toStringAsFixed(2),
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                  ),
                  Text(
                    maxValue.toStringAsFixed(2),
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                  ),
                ],
              )
            ],
          )
        : Row(
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
                      stops: [0.0, 0.33, 0.66, 1.0],
                    ),
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black54,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                maxValue.toStringAsFixed(2),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
              ),
            ],
          );
  }
}

