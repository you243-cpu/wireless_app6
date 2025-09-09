import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CSVService {
  static Future<Map<String, List<dynamic>>> parseCSV(String raw) async {
    final rows = const CsvToListConverter().convert(raw, eol: "\n");
    return _toMap(rows);
  }

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

  static Map<String, List<dynamic>> _toMap(List<List<dynamic>> rows) {
    List<double> pH = [];
    List<double> n = [];
    List<double> p = [];
    List<double> k = [];
    List<DateTime> timestamps = [];

    for (var i = 1; i < rows.length; i++) {
      try {
        timestamps.add(DateTime.parse(rows[i][0]));
        pH.add(rows[i][1].toDouble());
        n.add(rows[i][2].toDouble());
        p.add(rows[i][3].toDouble());
        k.add(rows[i][4].toDouble());
      } catch (_) {}
    }
    return {"pH": pH, "N": n, "P": p, "K": k, "timestamps": timestamps};
  }
}
