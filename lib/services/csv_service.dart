import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CSVService {
  /// Parse CSV from a raw string
  static Future<Map<String, List<dynamic>>> parseCSV(String raw) async {
    final rows = const CsvToListConverter().convert(raw, eol: "\n");
    return _toMap(rows);
  }

  /// Pick a CSV file using file picker
  static Future<Map<String, List<dynamic>>?> pickCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      final file = File(result.files.single.path!);
      final rawData = await file.readAsString();
      final rows = const CsvToListConverter().convert(rawData, eol: "\n");
      return _toMap(rows);
    }
    return null;
  }

  /// Convert CSV rows into structured Map
  static Map<String, List<dynamic>> _toMap(List<List<dynamic>> rows) {
    List<DateTime> timestamps = [];
    List<double> latitudes = [];
    List<double> longitudes = [];
    List<double> pH = [];
    List<double> temperature = [];
    List<double> humidity = [];
    List<double> ec = [];
    List<double> n = [];
    List<double> p = [];
    List<double> k = [];

    for (var i = 1; i < rows.length; i++) {
      try {
        // Expected CSV format:
        // timestamp, lat, lon, pH, temperature, humidity, ec, n, p, k
        timestamps.add(DateTime.parse(rows[i][0].toString()));
        latitudes.add(rows[i][1].toDouble());
        longitudes.add(rows[i][2].toDouble());
        pH.add(rows[i][3].toDouble());
        temperature.add(rows[i][4].toDouble());
        humidity.add(rows[i][5].toDouble());
        ec.add(rows[i][6].toDouble());
        n.add(rows[i][7].toDouble());
        p.add(rows[i][8].toDouble());
        k.add(rows[i][9].toDouble());
      } catch (e) {
        // Skip bad rows silently
        continue;
      }
    }

    return {
      "timestamps": timestamps,
      "latitudes": latitudes,
      "longitudes": longitudes,
      "pH": pH,
      "temperature": temperature,
      "humidity": humidity,
      "ec": ec,
      "N": n,
      "P": p,
      "K": k,
    };
  }
}
