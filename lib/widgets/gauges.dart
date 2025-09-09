import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/alert_service.dart';

class Gauges extends StatelessWidget {
  final double pH;
  const Gauges({super.key, required this.pH});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularPercentIndicator(
          radius: 60,
          lineWidth: 12,
          percent: (pH / 14).clamp(0.0, 1.0),
          center: Text(pH.toStringAsFixed(2)),
          progressColor: AlertService.getpHColor(pH),
          footer: const Text("pH"),
        ),
      ],
    );
  }
}

