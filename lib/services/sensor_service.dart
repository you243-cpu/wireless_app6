import 'dart:convert';
import 'package:http/http.dart' as http;

class SensorData {
  final double pH;
  final int N, P, K;
  final List<double> pHReadings, nReadings, pReadings, kReadings;
  final List<DateTime> timestamps;

  SensorData({
    required this.pH,
    required this.N,
    required this.P,
    required this.K,
    required this.pHReadings,
    required this.nReadings,
    required this.pReadings,
    required this.kReadings,
    required this.timestamps,
  });
}

class SensorService {
  static const String espIP = "192.168.4.1"; // ESP8266 IP

  static Future<void> fetchSensorData({required Function(SensorData) onData}) async {
    try {
      final response = await http.get(Uri.parse("http://$espIP/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final now = DateTime.now();

        final sensorData = SensorData(
          pH: (data["pH"] as num).toDouble(),
          N: data["N"],
          P: data["P"],
          K: data["K"],
          pHReadings: [(data["pH"] as num).toDouble()],
          nReadings: [(data["N"] as num).toDouble()],
          pReadings: [(data["P"] as num).toDouble()],
          kReadings: [(data["K"] as num).toDouble()],
          timestamps: [now],
        );

        onData(sensorData);
      }
    } catch (e) {
      print("Fetch error: $e");
    }
  }
}
