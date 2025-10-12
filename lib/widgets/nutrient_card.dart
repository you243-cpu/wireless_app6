import 'package:flutter/material.dart';

class NutrientCard extends StatelessWidget {
  final int N;
  final int P;
  final int K;
  final String? plantStatus;

  const NutrientCard({
    super.key,
    required this.N,
    required this.P,
    required this.K,
    this.plantStatus,
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
            if ((plantStatus ?? '').isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.local_florist, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      plantStatus!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
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
