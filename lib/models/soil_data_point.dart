class SoilDataPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  final double pH;
  final double temperature;
  final double humidity;
  final double ec;
  final double n;
  final double p;
  final double k;

  SoilDataPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.pH,
    required this.temperature,
    required this.humidity,
    required this.ec,
    required this.n,
    required this.p,
    required this.k,
  });
}
