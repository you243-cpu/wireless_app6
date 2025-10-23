import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartWidget extends StatelessWidget {
  final List<double> data;
  final List<DateTime> timestamps;
  final String label;
  final Color color;

  final double zoomLevel;
  final int scrollIndex;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.timestamps,
    required this.label,
    required this.color,
    this.zoomLevel = 1.0,
    this.scrollIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No data"));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final axisColor = isDark ? Colors.white70 : Colors.black87;
    final gridColor = isDark ? Colors.white24 : Colors.black26;

    // Determine visible window
    int visibleCount = (timestamps.length ~/ zoomLevel).clamp(1, timestamps.length);
    int start = scrollIndex.clamp(0, (timestamps.length - visibleCount).clamp(0, timestamps.length));
    int end = (start + visibleCount).clamp(0, timestamps.length);

    final shownData = data.sublist(start, end);
    final List<FlSpot> spots = [
      for (int i = 0; i < shownData.length; i++)
        if (shownData[i].isFinite) FlSpot(i.toDouble(), shownData[i]),
    ];
    final shownTimestamps = timestamps.sublist(start, end);

    // Compute a comfortable Y-range with padding for readability
    final finiteValues = shownData.where((v) => v.isFinite).toList();
    double minY = finiteValues.isNotEmpty ? finiteValues.reduce(math.min) : 0.0;
    double maxY = finiteValues.isNotEmpty ? finiteValues.reduce(math.max) : 1.0;
    if (minY == maxY) {
      // Avoid a flat line occupying the border
      minY -= 1;
      maxY += 1;
    } else {
      final padding = (maxY - minY) * 0.1;
      minY -= padding;
      maxY += padding;
    }

    // Build date title: single date or date range
    final DateFormat dateFmt = DateFormat('MMM d, yyyy');
    final DateFormat timeFmt = DateFormat('HH:mm');
    final String dateTitle = shownTimestamps.isEmpty
        ? ''
        : (DateTime(shownTimestamps.first.year, shownTimestamps.first.month, shownTimestamps.first.day) ==
                DateTime(shownTimestamps.last.year, shownTimestamps.last.month, shownTimestamps.last.day)
            ? dateFmt.format(shownTimestamps.first)
            : "${dateFmt.format(shownTimestamps.first)} – ${dateFmt.format(shownTimestamps.last)}");

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final targetHeight = (constraints.maxHeight.isFinite
                ? constraints.maxHeight * 0.55
                : screenHeight * 0.35)
            .clamp(220.0, 420.0) as double;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with label and latest value
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                      ),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        shownData.isNotEmpty ? shownData.last.toStringAsFixed(2) : '-',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: axisColor),
                      ),
                    ],
                  ),
                  if (dateTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dateTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: axisColor),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: targetHeight,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: isDark ? const Color(0xFF111315) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 18, 8),
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              drawHorizontalLine: true,
                              getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.6),
                              getDrawingVerticalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.6),
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 24,
                                  interval: shownTimestamps.isEmpty ? 1 : (shownTimestamps.length <= 6 ? 1 : (shownTimestamps.length / 6).floorToDouble()),
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index < 0 || index >= shownTimestamps.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final dt = shownTimestamps[index];
                                    return Text(
                                      timeFmt.format(dt),
                                      style: TextStyle(fontSize: 10, color: axisColor),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: TextStyle(fontSize: 10, color: axisColor),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                tooltipRoundedRadius: 8,
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      spot.y.toStringAsFixed(2),
                                      TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: color,
                                barWidth: 2,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      color.withOpacity(0.18),
                                      color.withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
