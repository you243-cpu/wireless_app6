import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class Gauges extends StatelessWidget {
  final double pH;
  final Color pHColor;

  const Gauges({
    Key? key,
    required this.pH,
    required this.pHColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 80,
      lineWidth: 12,
      percent: (pH / 14).clamp(0.0, 1.0),
      center: Text("pH ${pH.toStringAsFixed(1)}"),
      progressColor: pHColor,
      backgroundColor: Colors.grey.shade300,
      circularStrokeCap: CircularStrokeCap.round,
    );
  }
}
