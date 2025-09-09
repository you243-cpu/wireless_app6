import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class GaugesWidget extends StatelessWidget {
  final double pH;

  const GaugesWidget({super.key, required this.pH});

  Color _getpHColor(double pH) {
    if (pH < 5.5 || pH > 7.5) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Soil pH",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 12,
              percent: (pH / 14).clamp(0.0, 1.0),
              center: Text(
                pH.toStringAsFixed(2),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              progressColor: _getpHColor(pH),
              backgroundColor: Colors.grey.shade200,
              circularStrokeCap: CircularStrokeCap.round,
              footer: const Padding(
                padding: EdgeInsets.only(top: 12.0),
                child: Text("pH Level"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
