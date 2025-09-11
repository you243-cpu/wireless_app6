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

    // skip header row
    for (var i = 1; i < rows.length; i++) {
      try {
        timestamps.add(DateTime.parse(rows[i][0].toString()));
        latitudes.add(double.parse(rows[i][1].toString()));
        longitudes.add(double.parse(rows[i][2].toString()));
        pH.add(double.parse(rows[i][3].toString()));
        temperature.add(double.parse(rows[i][4].toString()));
        humidity.add(double.parse(rows[i][5].toString()));
        ec.add(double.parse(rows[i][6].toString()));
        n.add(double.parse(rows[i][7].toString()));
        p.add(double.parse(rows[i][8].toString()));
        k.add(double.parse(rows[i][9].toString()));
      } catch (e) {
        print("Skipping bad row $i: $e");
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
      "EC": ec, // 🔑 normalize key to "EC"
      "N": n,
      "P": p,
      "K": k,
    };
  }
}
