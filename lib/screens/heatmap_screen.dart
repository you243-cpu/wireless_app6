import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/heatmap_service.dart'; // Contains HeatmapGrid
import '../services/heatmap_cache_service.dart';
import '../services/csv_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/heatmap_2d.dart';
import '../widgets/heatmap_3d.dart';
import '../widgets/heatmap_surface_3d.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../services/gltf_service.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_settings.dart';
import '../providers/csv_data_provider.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final heatmapService = HeatmapService();
  final List<String> metrics = [
    'pH',
    'Temperature',
    'Humidity',
    'EC',
    'N',
    'P',
    'K',
    'All'
  ];
  String currentMetric = 'All';
  DateTime? startTime;
  DateTime? endTime;
  bool is3DView = false;
  // Store last computed grid and metric to enable caching for user CSVs too
  String? _lastKeySeed; // Either asset content or provider dataset hash
  bool _lastKeyIsRaw = false; // true when seed is a raw key (not a file path)
  bool isLoading = true;
  List<List<double>>? gridData;
  double minValue = 0.0;
  double maxValue = 0.0;
  double geographicWidthRatio = 1.0; // NEW: Aspect ratio for shape correction
  String? gltfModelPath;
  Key _modelViewerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If provider data changes while on this screen, refresh
    try {
      final provider = context.read<CSVDataProvider>();
      if (provider.hasData && provider.sourceKey.isNotEmpty && provider.sourceKey != _lastKeySeed) {
        final points = _pointsFromProvider(provider);
        heatmapService.setPoints(points);
        setState(() {
          startTime = provider.timestamps.reduce((a, b) => a.isBefore(b) ? a : b);
          endTime = provider.timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
          currentMetric = 'All';
          isLoading = false;
          _lastKeySeed = provider.sourceKey;
          _lastKeyIsRaw = true;
        });
        _updateGridAndValues();
        unawaited(_ensurePngForCurrent(_lastKeySeed!, isRawKey: true));
      }
    } catch (_) {}
  }

  List<HeatmapPoint> _pointsFromParsed(Map<String, List<dynamic>> parsed) {
    final timestamps = parsed['timestamps']?.cast<DateTime>() ?? <DateTime>[];
    final lats = parsed['latitudes']?.cast<double>() ?? <double>[];
    final lons = parsed['longitudes']?.cast<double>() ?? <double>[];
    if (timestamps.isEmpty || lats.isEmpty || lons.isEmpty) return [];

    // Map unique lat/lon to grid indices
    final uniqueLats = lats.toSet().toList()..sort();
    final uniqueLons = lons.toSet().toList()..sort();
    final latToY = {for (int i = 0; i < uniqueLats.length; i++) uniqueLats[i]: i};
    final lonToX = {for (int i = 0; i < uniqueLons.length; i++) uniqueLons[i]: i};

    List<HeatmapPoint> pts = [];
    for (int i = 0; i < timestamps.length; i++) {
      final t = timestamps[i];
      final lat = lats[i];
      final lon = lons[i];
      if (t == null || lat.isNaN || lon.isNaN) continue;
      final metrics = <String, double>{
        'pH': (parsed['pH']?[i] as double?) ?? double.nan,
        'Temperature': (parsed['temperature']?[i] as double?)?.toDouble() ?? double.nan,
        'Humidity': (parsed['humidity']?[i] as double?)?.toDouble() ?? double.nan,
        'EC': (parsed['ec']?[i] as double?)?.toDouble() ?? double.nan,
        'N': (parsed['N']?[i] as double?)?.toDouble() ?? double.nan,
        'P': (parsed['P']?[i] as double?)?.toDouble() ?? double.nan,
        'K': (parsed['K']?[i] as double?)?.toDouble() ?? double.nan,
      };
      pts.add(HeatmapPoint(
        x: lonToX[lon] ?? 0,
        y: latToY[lat] ?? 0,
        t: t,
        metrics: metrics,
      ));
    }
    return pts;
  }

  List<HeatmapPoint> _pointsFromProvider(CSVDataProvider provider) {
    final timestamps = provider.timestamps;
    final lats = provider.latitudes;
    final lons = provider.longitudes;
    if (timestamps.isEmpty || lats.isEmpty || lons.isEmpty) return [];

    final uniqueLats = lats.toSet().toList()..sort();
    final uniqueLons = lons.toSet().toList()..sort();
    final latToY = {for (int i = 0; i < uniqueLats.length; i++) uniqueLats[i]: i};
    final lonToX = {for (int i = 0; i < uniqueLons.length; i++) uniqueLons[i]: i};

    final List<HeatmapPoint> pts = [];
    for (int i = 0; i < timestamps.length; i++) {
      final t = timestamps[i];
      final lat = lats[i];
      final lon = lons[i];
      if (lat.isNaN || lon.isNaN) continue;
      final metrics = <String, double>{
        'pH': (i < provider.pH.length) ? provider.pH[i] : double.nan,
        'Temperature': (i < provider.temperature.length) ? provider.temperature[i] : double.nan,
        'Humidity': (i < provider.humidity.length) ? provider.humidity[i] : double.nan,
        'EC': (i < provider.ec.length) ? provider.ec[i] : double.nan,
        'N': (i < provider.n.length) ? provider.n[i] : double.nan,
        'P': (i < provider.p.length) ? provider.p[i] : double.nan,
        'K': (i < provider.k.length) ? provider.k[i] : double.nan,
      };
      pts.add(HeatmapPoint(
        x: lonToX[lon] ?? 0,
        y: latToY[lat] ?? 0,
        t: t,
        metrics: metrics,
        lat: lat,
        lon: lon,
      ));
    }
    return pts;
  }

  Future<void> _loadData() async {
    try {
      // Prefer live provider CSV if available
      final provider = context.read<CSVDataProvider>();
      if (provider.hasData) {
        final points = _pointsFromProvider(provider);
        heatmapService.setPoints(points);
        if (!mounted) return;
        setState(() {
          startTime = provider.timestamps.reduce((a, b) => a.isBefore(b) ? a : b);
          endTime = provider.timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
          currentMetric = 'All';
          isLoading = false;
          _lastKeySeed = provider.sourceKey;
          _lastKeyIsRaw = true;
        });
        _updateGridAndValues();
        await _ensurePngForCurrent(_lastKeySeed!, isRawKey: true);
        return;
      }

      // Fallback: use default asset (lat/lon/timestamp grid)
      final csvAssetPath = 'assets/simulated_soil_square.csv';
      List<HeatmapPoint> points = await HeatmapService.parseCsvAsset(csvAssetPath);
      if (points.isEmpty) {
        final csvString = await rootBundle.loadString(csvAssetPath);
        final parsed = await CSVService.parseCSV(csvString);
        points = _pointsFromParsed(parsed);
      }
      heatmapService.setPoints(points);

      if (!mounted) return;

      if (points.isNotEmpty) {
        // Compute full available time range from CSV
        final DateTime minT = points.map((p) => p.t).reduce((a, b) => a.isBefore(b) ? a : b);
        final DateTime maxT = points.map((p) => p.t).reduce((a, b) => a.isAfter(b) ? a : b);

        setState(() {
          startTime = minT;
          endTime = maxT;
          // Start with 'All' to ensure visibility by default
          currentMetric = 'All';
          isLoading = false;
        });
        _updateGridAndValues();
        // After grid computed, auto-generate PNG for default metric if missing
        _lastKeySeed = csvAssetPath;
        _lastKeyIsRaw = false;
        await _ensurePngForCurrent(csvAssetPath);
        // Fallback: if grid looks empty, try metric 'pH' then 'All' with full range again
        if (!_hasFinite(gridData)) {
          setState(() { currentMetric = 'pH'; });
          _updateGridAndValues();
          if (!_hasFinite(gridData)) {
            setState(() { currentMetric = 'All'; startTime = minT; endTime = maxT; });
            _updateGridAndValues();
          }
        }
      } else {
        // Ensure spinner clears even when dataset is empty
        setState(() {
          startTime = null;
          endTime = null;
          gridData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateGridAndValues() {
    if (heatmapService.points.isEmpty || startTime == null || endTime == null) {
      setState(() {
        gridData = [];
        minValue = 0;
        maxValue = 0;
        geographicWidthRatio = 1.0; // Reset ratio
      });
      return;
    }

    // Prefer lat/lon seamless grid if available
    // CHANGE: Function now returns HeatmapGrid
    final HeatmapGrid heatmapData = heatmapService.createUniformGridFromLatLon(
      metric: currentMetric,
      start: startTime!,
      end: endTime!,
      // Optional: upsample if only a few unique coords
      targetCols: null,
      targetRows: null,
    );

    final newGrid = heatmapData.grid; // Extract grid data
    final allValues = newGrid.expand((row) => row).where((v) => !v.isNaN).toList();
    
    if (allValues.isNotEmpty) {
      final min = allValues.reduce((a, b) => a < b ? a : b);
      final max = allValues.reduce((a, b) => a > b ? a : b);

      double adjustedMin = min;
      double adjustedMax = max;
      if (adjustedMin == adjustedMax) {
        adjustedMin = adjustedMin - 0.01;
        adjustedMax = adjustedMax + 0.01;
      }

      setState(() {
        gridData = newGrid;
        minValue = adjustedMin;
        maxValue = adjustedMax;
        geographicWidthRatio = heatmapData.widthRatio; // NEW: Set aspect ratio
      });
    } else {
      // When no finite values are present, still provide a non-zero range for UI
      setState(() {
        gridData = newGrid;
        minValue = 0;
        maxValue = 1;
        geographicWidthRatio = heatmapData.widthRatio; // NEW: Still set ratio even if empty
      });
    }
  }

  Future<void> _ensurePngForCurrent(String keySeed, {bool isRawKey = false}) async {
    try {
      if (gridData == null || gridData!.isEmpty) return;
      // Create a stable key from dataset seed + metric
      final String seed = isRawKey
          ? keySeed
          : await DefaultAssetBundle.of(context).loadString(keySeed);
      final key = HeatmapCacheService.buildKey(csvContent: seed, metric: currentMetric);
      final settings = context.read<AppSettings>();
      final exists = await HeatmapCacheService.existsPng(key, basePath: settings.saveDirectory);
      if (!exists) {
        final img = await renderHeatmapImage(
          grid: gridData!,
          metricLabel: currentMetric,
          minValue: minValue,
          maxValue: maxValue,
          cellSize: 24,
        );
        await HeatmapCacheService.writePng(key, img, basePath: settings.saveDirectory);
      }
    } catch (_) {
      // Ignore caching errors silently for now
    }
  }

  Widget _buildTexturedPlaneViewer() {
    // Build/locate PNG for current metric and return a model-viewer with a plane textured by it
    return FutureBuilder<String>(
      future: _buildOrGetGltfDataUriForCurrent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final uri = snapshot.data!;
        return ModelViewer(
          key: _modelViewerKey,
          src: uri,
          cameraControls: true,
          autoRotate: false,
          ar: false,
          disableZoom: false,
          exposure: 1.0,
          cameraOrbit: '0deg 65deg 100%',
          fieldOfView: '45deg',
          alt: 'Textured heatmap plane',
        );
      },
    );
  }

  Future<String> _buildOrGetGltfDataUriForCurrent() async {
    // Ensure PNG exists for current dataset
    String seed;
    if (_lastKeySeed != null) {
      seed = _lastKeyIsRaw
          ? _lastKeySeed!
          : await DefaultAssetBundle.of(context).loadString(_lastKeySeed!);
    } else {
      // fallback to asset
      seed = await DefaultAssetBundle.of(context).loadString('assets/simulated_soil_square.csv');
    }
    final key = HeatmapCacheService.buildKey(csvContent: seed, metric: currentMetric);
    final settings = context.read<AppSettings>();
    if (!await HeatmapCacheService.existsPng(key, basePath: settings.saveDirectory)) {
      if (gridData != null && gridData!.isNotEmpty) {
        final img = await renderHeatmapImage(
          grid: gridData!,
          metricLabel: currentMetric,
          minValue: minValue,
          maxValue: maxValue,
          cellSize: 24,
        );
        await HeatmapCacheService.writePng(key, img, basePath: settings.saveDirectory);
      }
    }
    // Read PNG and embed in glTF JSON (data URIs)
    final pngFile = await HeatmapCacheService.getPngFile(key, basePath: settings.saveDirectory);
    final bytes = await pngFile.readAsBytes();
    final json = GltfService.buildTexturedPlaneGltfJson(bytes);
    return GltfService.gltfJsonToDataUri(json);
  }

  bool _hasFinite(List<List<double>>? grid) {
    if (grid == null || grid.isEmpty || grid.first.isEmpty) return false;
    for (final row in grid) {
      for (final v in row) {
        if (v.isFinite) return true;
      }
    }
    return false;
  }

  void _onMetricChanged(String newMetric) {
    setState(() {
      currentMetric = newMetric;
      // Force 3D viewer to reload when metric changes
      if (is3DView) {
        _modelViewerKey = UniqueKey();
      }
    });
    _updateGridAndValues();
    // Try generating PNG for this metric in background
    if (_lastKeySeed != null) {
      unawaited(_ensurePngForCurrent(_lastKeySeed!, isRawKey: _lastKeyIsRaw));
    }
  }

  Future<void> _selectDateRange() async {
    // Show date picker first
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: startTime ?? DateTime.now(),
    );

    if (pickedDate != null) {
      // Then show time picker
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(startTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        final newStartTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          startTime = newStartTime;
          endTime = newStartTime.add(const Duration(hours: 1)); // Set a default end time
        });
        _updateGridAndValues();
      }
    }
  }

  void _toggleView() {
    setState(() {
      is3DView = !is3DView;
    });

    // In this app we render 3D with a custom painter instead of glTF assets
    gltfModelPath = null;
  }

  void _reset3DView() {
    // Not used in custom painter (double-tap inside canvas resets),
    // but for the model_viewer, we can reload the scene to reset camera.
    setState(() {
      _modelViewerKey = UniqueKey(); // force widget reload
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap Viewer'),
        backgroundColor: isDark ? Colors.grey[800] : Colors.blue,
        actions: [
          IconButton(
            icon: Icon(is3DView ? Icons.view_agenda : Icons.view_in_ar),
            onPressed: _toggleView,
            tooltip: 'Toggle 2D/3D View',
          ),
          if (is3DView)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset 3D view',
              onPressed: _reset3DView,
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Set image save directory',
            onPressed: () async {
              await _promptSaveDirectory(context);
            },
          ),
        ],
      ),
      body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: metrics.map((metric) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ElevatedButton(
                            onPressed: () => _onMetricChanged(metric),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentMetric == metric
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(metric),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      startTime != null && endTime != null
                          ? 'Viewing Data from ${startTime!.toString().split('.')[0]} to ${endTime!.toString().split('.')[0]}'
                          : 'Select Date & Time Range',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: (gridData != null && gridData!.isNotEmpty)
                        ? (is3DView
                            ? _buildTexturedPlaneViewer()
                            : Heatmap2D(
                                grid: gridData!,
                                geographicWidthRatio: geographicWidthRatio, // PASS THE NEW RATIO HERE
                                metricLabel: currentMetric,
                                minValue: minValue,
                                maxValue: maxValue,
                              ))
                        : const Center(
                            child: Text("No data to display for the selected metric and time range."),
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (!is3DView && (gridData != null && gridData!.isNotEmpty))
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export heatmap PNG'),
                      onPressed: () async {
                        try {
                          final img = await renderHeatmapImage(
                            grid: gridData!,
                            metricLabel: currentMetric,
                            minValue: minValue,
                            maxValue: maxValue,
                            cellSize: 16,
                            showGridLines: false,
                          );
                          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
                          if (bytes != null) {
                          final settings = context.read<AppSettings>();
                          // Normalize and avoid duplicating 'heatmaps' folder name
                          Directory base;
                          if (settings.saveDirectory.isNotEmpty) {
                            base = Directory(settings.saveDirectory);
                          } else {
                            base = await getApplicationDocumentsDirectory();
                          }
                          final String normalizedBase = base.path.replaceAll('\\', '/').replaceAll(RegExp(r"/+$"), '');
                          final bool endsWithHeatmaps = normalizedBase.toLowerCase().endsWith('/heatmaps');
                          final Directory exportDir = Directory(endsWithHeatmaps ? normalizedBase : '$normalizedBase/heatmaps');
                          if (!await exportDir.exists()) {
                            await exportDir.create(recursive: true);
                          }
                            final safeMetric = currentMetric.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
                            final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
                            final path = '${exportDir.path}/heatmap_${safeMetric}_$timestamp.png';
                            final file = File(path);
                            try {
                              await file.writeAsBytes(bytes.buffer.asUint8List());
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Saved PNG: $path')),
                                );
                              }
                            } on FileSystemException catch (e) {
                              // Fallback to app documents dir when permission denied
                              final fallbackBase = await getApplicationDocumentsDirectory();
                              final fallbackDir = Directory('${fallbackBase.path}/heatmaps');
                              if (!await fallbackDir.exists()) {
                                await fallbackDir.create(recursive: true);
                              }
                              final fallbackPath = '${fallbackDir.path}/heatmap_${safeMetric}_$timestamp.png';
                              final fallbackFile = File(fallbackPath);
                              await fallbackFile.writeAsBytes(bytes.buffer.asUint8List());
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Saved to app storage (no permission for chosen dir). Path: $fallbackPath')),
                                );
                              }
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to encode PNG bytes')),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to render PNG: $e')),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _promptSaveDirectory(BuildContext context) async {
    final controller = TextEditingController(
      text: context.read<AppSettings>().saveDirectory,
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set save directory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Directory path',
                  hintText: '/storage/emulated/0/Download',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse...'),
                  onPressed: () async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) {
                      controller.text = path;
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tip: Choose a writable folder (not root of /storage). Files go into a heatmaps subfolder.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<AppSettings>().setSaveDirectory(controller.text.trim());
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
