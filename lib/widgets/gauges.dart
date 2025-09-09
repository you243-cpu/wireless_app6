import 'package:flutter/material.dart';

class GaugeWidget extends StatelessWidget {
  final double value;
  final String label;
  final String unit;

  const GaugeWidget({
    super.key,
    required this.value,
    required this.label,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "$value $unit",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
