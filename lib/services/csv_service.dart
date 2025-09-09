import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CSVService {
  static Future<Map<String, List<dynamic>>> loadCSV(String path) async {
    final raw = await rootBundle.loadString(path);
    List<List<dynamic>> rows = const CsvToListConverter().convert(raw);

    List<double> pH = [];
    List<double> N = [];
    List<double> P = [];
    List<double> K = [];
    List<DateTime> timestamps = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      timestamps.add(DateTime.tryParse(row[0].toString()) ?? DateTime.now());
      pH.add(row[1].toDouble());
      N.add(row[2].toDouble());
      P.add(row[3].toDouble());
      K.add(row[4].toDouble());
    }

    return {
      'timestamps': timestamps,
      'pH': pH,
      'N': N,
      'P': P,
      'K': K,
    };
  }
}
