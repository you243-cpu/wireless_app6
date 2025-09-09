import 'package:flutter/material.dart';

class NutrientCard extends StatelessWidget {
  final int N, P, K;
  const NutrientCard({super.key, required this.N, required this.P, required this.K});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.science, color: Colors.blue),
            title: const Text("Nitrogen (N)"),
            trailing: Text("$N mg/kg"),
          ),
          ListTile(
            leading: const Icon(Icons.science, color: Colors.orange),
            title: const Text("Phosphorus (P)"),
            trailing: Text("$P mg/kg"),
          ),
          ListTile(
            leading: const Icon(Icons.science, color: Colors.purple),
            title: const Text("Potassium (K)"),
            trailing: Text("$K mg/kg"),
          ),
        ],
      ),
    );
  }
}

