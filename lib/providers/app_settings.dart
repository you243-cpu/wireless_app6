import 'package:flutter/foundation.dart';

class AppSettings extends ChangeNotifier {
  String _saveDirectory = '';
  Set<String> _selectedMetrics = {};
  String _dataDirectory = '';

  // Advanced segmentation/grouping settings
  int _timeGapMinutes = 60; // split runs when gap > minutes
  bool _enableFarmGrouping = true;
  bool _enableRerunDetection = true;
  double _farmCentroidThresholdMeters = 160.0; // cluster centroid proximity
  double _bboxIoUThreshold = 0.5; // overlap threshold
  double _endpointNearMeters = 90.0; // reversed endpoints proximity

  String get saveDirectory => _saveDirectory;
  Set<String> get selectedMetrics => _selectedMetrics;
  String get dataDirectory => _dataDirectory;

  int get timeGapMinutes => _timeGapMinutes;
  bool get enableFarmGrouping => _enableFarmGrouping;
  bool get enableRerunDetection => _enableRerunDetection;
  double get farmCentroidThresholdMeters => _farmCentroidThresholdMeters;
  double get bboxIoUThreshold => _bboxIoUThreshold;
  double get endpointNearMeters => _endpointNearMeters;

  void setSaveDirectory(String dir) {
    _saveDirectory = dir;
    notifyListeners();
  }

  void setSelectedMetrics(Set<String> metrics) {
    _selectedMetrics = metrics;
    notifyListeners();
  }

  void setDataDirectory(String dir) {
    _dataDirectory = dir;
    notifyListeners();
  }

  void setTimeGapMinutes(int minutes) {
    _timeGapMinutes = minutes.clamp(1, 1440);
    notifyListeners();
  }

  void setEnableFarmGrouping(bool value) {
    _enableFarmGrouping = value;
    notifyListeners();
  }

  void setEnableRerunDetection(bool value) {
    _enableRerunDetection = value;
    notifyListeners();
  }

  void setFarmCentroidThresholdMeters(double meters) {
    _farmCentroidThresholdMeters = meters.clamp(1.0, 5000.0);
    notifyListeners();
  }

  void setBboxIoUThreshold(double v) {
    _bboxIoUThreshold = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setEndpointNearMeters(double meters) {
    _endpointNearMeters = meters.clamp(1.0, 5000.0);
    notifyListeners();
  }
}
