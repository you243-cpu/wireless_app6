import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Heatmap3DViewer extends StatelessWidget {
  final String gltfModelPath;

  const Heatmap3DViewer({super.key, required this.gltfModelPath});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              "A functional 3D viewer is not supported in this environment.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "This would require a dedicated 3D rendering library like Three.js, which is not available in this limited context.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
