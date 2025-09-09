import 'package:flutter/material.dart';

class NutrientCard extends StatelessWidget {
  final double N, P, K;

  const NutrientCard({
    super.key,
    required this.N,
    required this.P,
    required this.K,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Nutrient Levels",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _nutrientBox("N", N, Colors.blue),
                _nutrientBox("P", P, Colors.orange),
                _nutrientBox("K", K, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientBox(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(value.toStringAsFixed(2)),
      ],
    );
  }
}
