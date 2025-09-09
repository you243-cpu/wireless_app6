import 'package:flutter/material.dart';
import '../services/alert_service.dart';

class SoilHealthCard extends StatelessWidget {
  final double pH;
  const SoilHealthCard({super.key, required this.pH});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Overall Soil Health", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              AlertService.getAlertMessage(pH),
              style: TextStyle(fontSize: 16, color: AlertService.getpHColor(pH)),
            ),
          ],
        ),
      ),
    );
  }
}

