import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvService {
  static Future<List<List<dynamic>>> loadDummyCSV() async {
    try {
      final csvString = await rootBundle.loadString('assets/data_aug24.csv');
      return const CsvToListConverter().convert(csvString, eol: "\n");
    } catch (e) {
      print("CSV load error: $e");
      return [];
    }
  }

  static Future<void> pickCsvFile(BuildContext context, State state) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final rawData = await file.readAsString();
        final rows = const CsvToListConverter().convert(rawData, eol: '\n');

        state.setState(() {
          loadCsvRows(rows, state);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loaded ${rows.length - 1} rows from CSV")),
        );
      }
    } catch (e) {
      print("CSV pick error: $e");
    }
  }

  static void loadCsvRows(List<List<dynamic>> rows, State state) {
    if (rows.isEmpty) return;

    state.setState(() {
      try {
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          (state as dynamic).timestamps.add(DateTime.parse(row[0]));
          (state).pHReadings.add(row[1].toDouble());
          (state).nReadings.add(row[2].toDouble());
          (state).pReadings.add(row[3].toDouble());
          (state).kReadings.add(row[4].toDouble());
        }
      } catch (e) {
        print("Row parse error: $e");
      }
    });
  }
}

