import 'package:flutter/material.dart';

class NutrientCard extends StatelessWidget {
  final double N;
  final double P;
  final double K;

  const NutrientCard({
    Key? key,
    required this.N,
    required this.P,
    required this.K,
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
            Text("Nutrient Levels",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildRow("Nitrogen (N)", N, Colors.blue),
            _buildRow("Phosphorus (P)", P, Colors.orange),
            _buildRow("Potassium (K)", K, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String name, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(value.toStringAsFixed(2), style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
