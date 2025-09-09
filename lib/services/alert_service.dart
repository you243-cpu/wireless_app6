import 'package:flutter/material.dart';

class AlertService {
  static String getAlertMessage(double pH) {
    if (pH < 5.5) return "⚠️ Soil too acidic. Add lime.";
    if (pH > 7.5) return "⚠️ Soil too alkaline. Add sulfur.";
    return "✅ Soil conditions look healthy!";
  }

  static Color getpHColor(double pH) {
    if (pH < 5.5 || pH > 7.5) return Colors.red;
    return Colors.green;
  }
}
