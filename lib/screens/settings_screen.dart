import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneral(settings, isDark),
          _buildAdvanced(settings, isDark),
        ],
      ),
    );
  }

  Widget _buildGeneral(AppSettings settings, bool isDark) {
    final saveDir = TextEditingController(text: settings.saveDirectory);
    final dataDir = TextEditingController(text: settings.dataDirectory);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Storage', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: saveDir,
          decoration: const InputDecoration(
            labelText: 'Heatmap Save Directory',
            hintText: '/storage/emulated/0/Download/heatmaps',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => context.read<AppSettings>().setSaveDirectory(v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: dataDir,
          decoration: const InputDecoration(
            labelText: 'App Data Directory',
            hintText: '/storage/emulated/0/Android/data/your.app',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => context.read<AppSettings>().setDataDirectory(v.trim()),
        ),
        const SizedBox(height: 24),
        Text('Display', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Additional general preferences can go here.'),
      ],
    );
  }

  Widget _buildAdvanced(AppSettings settings, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Run Segmentation', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('Time gap threshold (minutes)')),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: settings.timeGapMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onFieldSubmitted: (v) {
                  final parsed = int.tryParse(v) ?? settings.timeGapMinutes;
                  context.read<AppSettings>().setTimeGapMinutes(parsed);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable farm grouping'),
          value: settings.enableFarmGrouping,
          onChanged: (v) => context.read<AppSettings>().setEnableFarmGrouping(v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('Farm centroid proximity (meters)')),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: settings.farmCentroidThresholdMeters.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onFieldSubmitted: (v) {
                  final parsed = double.tryParse(v) ?? settings.farmCentroidThresholdMeters;
                  context.read<AppSettings>().setFarmCentroidThresholdMeters(parsed);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('BBox IoU threshold (0..1)')),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: settings.bboxIoUThreshold.toStringAsFixed(2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onFieldSubmitted: (v) {
                  final parsed = double.tryParse(v) ?? settings.bboxIoUThreshold;
                  context.read<AppSettings>().setBboxIoUThreshold(parsed);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('These thresholds influence farm clustering.'),
      ],
    );
  }
}
