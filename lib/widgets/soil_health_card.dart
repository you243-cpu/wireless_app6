import 'package:flutter/material.dart';

class SoilHealthCard extends StatelessWidget {
  final String message;

  const SoilHealthCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.eco, color: Colors.green, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
