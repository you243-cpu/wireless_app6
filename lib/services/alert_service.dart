import 'package:flutter/material.dart';

class AlertService {
  static void checkAlerts(
    BuildContext context, {
    required double pH,
    required double soilHealth,
  }) {
    if (soilHealth < 50) {
      _showAlert(context, "Low Soil Health", "Overall soil health is poor!");
    }
    if (pH < 5.5 || pH > 8.0) {
      _showAlert(context, "pH Warning", "Soil pH is outside optimal range!");
    }
  }

  static void _showAlert(BuildContext context, String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    });
  }
}
