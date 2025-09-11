// lib/widgets/heatmap_3d.dart
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class Heatmap3DViewer extends StatelessWidget {
  final String gltfModelPath;

  const Heatmap3DViewer({
    super.key,
    required this.gltfModelPath,
  });

  @override
  Widget build(BuildContext context) {
    if (gltfModelPath.isEmpty) {
      return const Center(
        child: Text("Generating 3D model..."),
      );
    }
    return ModelViewer(
      src: gltfModelPath,
      ar: false, // Augmented reality is disabled for a heatmap
      autoRotate: true,
      cameraControls: true,
      shadowIntensity: 1,
      // You can add other properties here to customize the viewer
    );
  }
}
