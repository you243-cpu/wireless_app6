class SensorService {
  static double calculateSoilHealth({
    required double pH,
    required double n,
    required double p,
    required double k,
  }) {
    double score = 0;

    if (pH >= 6.0 && pH <= 7.5) score += 25;
    if (n > 10) score += 25;
    if (p > 5) score += 25;
    if (k > 5) score += 25;

    return score;
  }
}
