// lib/providers/csv_data_provider.dart
import 'package:flutter/material.dart';

class CSVDataProvider extends ChangeNotifier {
  List<double> pH = [];
  List<double> temperature = [];
  List<double> humidity = [];
  List<double> ec = [];
  List<double> n = [];
  List<double> p = [];
  List<double> k = [];
  List<DateTime> timestamps = [];
  List<double> latitudes = [];
  List<double> longitudes = [];

  void updateData({
    required List<double> pH,
    required List<double> temperature,
    required List<double> humidity,
    required List<double> ec,
    required List<double> n,
    required List<double> p,
    required List<double> k,
    required List<DateTime> timestamps,
    required List<double> latitudes,
    required List<double> longitudes,
  }) {
    this.pH = pH;
    this.temperature = temperature;
    this.humidity = humidity;
    this.ec = ec;
    this.n = n;
    this.p = p;
    this.k = k;
    this.timestamps = timestamps;
    this.latitudes = latitudes;
    this.longitudes = longitudes;
    notifyListeners();
  }

  bool get hasData => timestamps.isNotEmpty;
}
