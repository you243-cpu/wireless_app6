import 'package:flutter/material.dart';

class NutrientCard extends StatelessWidget {
  final int N;
  final int P;
  final int K;

  const NutrientCard({
    super.key,
    required this.N,
    required this.P,
    required this.K,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("NPK Levels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrient("N", N, Colors.blue),
                _buildNutrient("P", P, Colors.orange),
                _buildNutrient("K", K, Colors.purple),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNutrient(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value.toString(), style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
