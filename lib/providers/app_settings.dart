import 'package:flutter/foundation.dart';

class AppSettings extends ChangeNotifier {
  String _saveDirectory = '';
  Set<String> _selectedMetrics = {};

  String get saveDirectory => _saveDirectory;
  Set<String> get selectedMetrics => _selectedMetrics;

  void setSaveDirectory(String dir) {
    _saveDirectory = dir;
    notifyListeners();
  }

  void setSelectedMetrics(Set<String> metrics) {
    _selectedMetrics = metrics;
    notifyListeners();
  }
}
