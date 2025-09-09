import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class SoilHealthCard extends StatelessWidget {
  final double score;

  const SoilHealthCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Overall Soil Health",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CircularPercentIndicator(
              radius: 60,
              lineWidth: 12,
              percent: (score / 100).clamp(0.0, 1.0),
              center: Text("${score.toStringAsFixed(1)}%"),
              progressColor: score > 70 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
