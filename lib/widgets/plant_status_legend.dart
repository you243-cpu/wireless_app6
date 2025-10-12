import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';

class PlantStatusLegend extends StatelessWidget {
  final Axis axis;
  final double spacing;
  final bool isDense;

  const PlantStatusLegend({super.key, this.axis = Axis.horizontal, this.spacing = 8.0, this.isDense = true});

  @override
  Widget build(BuildContext context) {
    final items = getPlantStatusLegendItems();
    final textStyle = Theme.of(context).textTheme.bodySmall;

    if (axis == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => _LegendItem(item: item, textStyle: textStyle, isDense: isDense)).toList(),
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items.map((item) => _LegendItem(item: item, textStyle: textStyle, isDense: isDense)).toList(),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final PlantStatusCategoryItem item;
  final TextStyle? textStyle;
  final bool isDense;

  const _LegendItem({required this.item, required this.textStyle, required this.isDense});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: isDense ? 12 : 16, height: isDense ? 12 : 16, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(item.label, style: textStyle),
      ],
    );
  }
}
