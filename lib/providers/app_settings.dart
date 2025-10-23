import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  String _saveDirectory = '';
  Set<String> _selectedMetrics = {};
  String _dataDirectory = '';

  // Appearance settings
  ThemeMode _themeMode = ThemeMode.dark; // default: dark as requested
  int _seedColorValue = const Color(0xFF2ECC71).value; // default: modern green

  // Advanced segmentation/grouping settings
  int _timeGapMinutes = 60; // split runs when gap > minutes
  bool _enableFarmGrouping = true;
  double _farmCentroidThresholdMeters = 160.0; // cluster centroid proximity
  double _bboxIoUThreshold = 0.5; // overlap threshold
  // rerun detection removed

  String get saveDirectory => _saveDirectory;
  Set<String> get selectedMetrics => _selectedMetrics;
  String get dataDirectory => _dataDirectory;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => Color(_seedColorValue);

  int get timeGapMinutes => _timeGapMinutes;
  bool get enableFarmGrouping => _enableFarmGrouping;
  double get farmCentroidThresholdMeters => _farmCentroidThresholdMeters;
  double get bboxIoUThreshold => _bboxIoUThreshold;
  // endpoint proximity removed

  // ----- Persistence -----
  static const _prefsThemeModeKey = 'appearance.themeMode';
  static const _prefsSeedColorKey = 'appearance.seedColor';

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

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsThemeModeKey, mode.name);
    } catch (_) {}
  }

  Future<void> setSeedColor(Color color) async {
    _seedColorValue = color.value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsSeedColorKey, _seedColorValue);
    } catch (_) {}
  }

  void setTimeGapMinutes(int minutes) {
    _timeGapMinutes = minutes.clamp(1, 1440);
    notifyListeners();
  }

  void setEnableFarmGrouping(bool value) {
    _enableFarmGrouping = value;
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

  // removed setter

  // Load persisted appearance settings
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_prefsThemeModeKey);
      if (themeName != null) {
        switch (themeName) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
      }
      final colorVal = prefs.getInt(_prefsSeedColorKey);
      if (colorVal != null) {
        _seedColorValue = colorVal;
      }
    } catch (_) {
      // ignore
    }
    notifyListeners();
  }
}
