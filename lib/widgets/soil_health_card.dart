import 'package:flutter/material.dart';

class SoilHealthCard extends StatelessWidget {
  final double pH;
  final String alertMessage;
  final Color pHColor;

  const SoilHealthCard({
    Key? key,
    required this.pH,
    required this.alertMessage,
    required this.pHColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Overall Soil Health",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text("pH: ${pH.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 20, color: pHColor)),
            const SizedBox(height: 8),
            Text(alertMessage, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
