import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

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

  /// Convert CSV rows into structured Map with dynamic header detection
  static Map<String, List<dynamic>> _toMap(List<List<dynamic>> rows) {
    if (rows.isEmpty) return {};

    // First row is header
    final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();

    // Map of columnName → list of values
    final Map<String, List<dynamic>> data = {
      "timestamps": [],
      "latitudes": [],
      "longitudes": [],
      "pH": [],
      "temperature": [],
      "humidity": [],
      "ec": [],
      "N": [],
      "P": [],
      "K": [],
      "plant_status": [],
    };

    // Helper to get index of a header safely
    int? idx(String name) {
      return headers.contains(name) ? headers.indexOf(name) : null;
    }

    // Iterate over data rows
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      try {
        if (idx("timestamp") != null) {
          final rawTs = row[idx("timestamp")!].toString();
          DateTime? parsed;
          try {
            parsed = DateTime.parse(rawTs);
          } catch (_) {
            try {
              // Accept single-digit hour (H) and space separator
              parsed = DateFormat('yyyy-MM-dd H:mm:ss').parse(rawTs);
            } catch (_) {
              parsed = null;
            }
          }
          if (parsed != null) {
            data["timestamps"]!.add(parsed);
          }
        }
        if (idx("lat") != null) {
          data["latitudes"]!.add(row[idx("lat")!].toDouble());
        }
        if (idx("lon") != null) {
          data["longitudes"]!.add(row[idx("lon")!].toDouble());
        }
        if (idx("ph") != null) {
          data["pH"]!.add(row[idx("ph")!].toDouble());
        }
        if (idx("temperature") != null) {
          data["temperature"]!.add(row[idx("temperature")!].toDouble());
        }
        if (idx("humidity") != null) {
          data["humidity"]!.add(row[idx("humidity")!].toDouble());
        }
        if (idx("ec") != null) {
          data["ec"]!.add(row[idx("ec")!].toDouble());
        }
        if (idx("n") != null) {
          data["N"]!.add(row[idx("n")!].toDouble());
        }
        if (idx("p") != null) {
          data["P"]!.add(row[idx("p")!].toDouble());
        }
        if (idx("k") != null) {
          data["K"]!.add(row[idx("k")!].toDouble());
        }
        if (idx("plant_status") != null) {
          final raw = row[idx("plant_status")!];
          data["plant_status"]!.add(raw?.toString().trim() ?? "");
        }
      } catch (e) {
        // Skip bad rows gracefully
        continue;
      }
    }

    return data;
  }

  /// Return the normalized headers from the CSV (first row)
  static List<String> getHeaders(List<List<dynamic>> rows) {
    if (rows.isEmpty) return [];
    return rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
  }
}

