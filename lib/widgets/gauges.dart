import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class GaugesWidget extends StatelessWidget {
  final double pH;

  const GaugesWidget({super.key, required this.pH});

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: "Soil pH",
        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 3,
          maximum: 10,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 3, endValue: 5.5, color: Colors.red),
            GaugeRange(startValue: 5.5, endValue: 7.5, color: Colors.green),
            GaugeRange(startValue: 7.5, endValue: 10, color: Colors.orange),
          ],
          pointers: <GaugePointer>[NeedlePointer(value: pH)],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                pH.toStringAsFixed(2),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            )
          ],
        )
      ],
    );
  }
}
