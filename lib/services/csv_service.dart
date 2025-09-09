// lib/services/csv_service.dart
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CsvService {
  // Load CSV from assets
  static Future<List<List<dynamic>>> loadFromAssets(String path) async {
    final csvString = await rootBundle.loadString(path);
    return const CsvToListConverter().convert(csvString, eol: "\n");
  }

  // Load CSV from a file
  static Future<List<List<dynamic>>> loadFromFile(File file) async {
    final rawData = await file.readAsString();
    return const CsvToListConverter().convert(rawData, eol: "\n");
  }

  // Parse CSV rows into sensor data
  static Map<String, List<dynamic>> parseRows(List<List<dynamic>> rows) {
    List<double> pHReadings = [];
    List<double> nReadings = [];
    List<double> pReadings = [];
    List<double> kReadings = [];
    List<DateTime> timestamps = [];

    for (var i = 1; i < rows.length; i++) {
      try {
        timestamps.add(DateTime.parse(rows[i][0]));
        pHReadings.add(rows[i][1].toDouble());
        nReadings.add(rows[i][2].toDouble());
        pReadings.add(rows[i][3].toDouble());
        kReadings.add(rows[i][4].toDouble());
      } catch (_) {
        // Ignore malformed rows
      }
    }

    return {
      "timestamps": timestamps,
      "pH": pHReadings,
      "N": nReadings,
      "P": pReadings,
      "K": kReadings,
    };
  }
}
