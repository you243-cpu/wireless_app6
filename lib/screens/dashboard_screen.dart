// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/csv_service.dart';
import '../services/alert_service.dart';
import '../widgets/soil_health_card.dart';
import '../widgets/gauges.dart';
import '../widgets/nutrient_card.dart';
import 'graph_screen.dart';
import 'heatmap_screen.dart';
import 'robot_control_screen.dart'; // Import the new screen
import '../widgets/metric_tile.dart';
import '../services/run_segmentation.dart';
import '../providers/csv_data_provider.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final String espIP = "192.168.4.1"; // ESP8266 IP

  // Current sensor values
  double pH = 7.0;
  double temperature = 25.0;
  double humidity = 50.0;
  double ec = 0.0;
  int N = 0, P = 0, K = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchSensorData());
    _loadAssetCSV();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Fetch live sensor values from ESP
  Future<void> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse("http://$espIP/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          pH = (data["pH"] ?? pH).toDouble();
          temperature = (data["temperature"] ?? temperature).toDouble();
          humidity = (data["humidity"] ?? humidity).toDouble();
          ec = (data["EC"] ?? ec).toDouble();
          N = data["N"] ?? N;
          P = data["P"] ?? P;
          K = data["K"] ?? K;
        });

        // Also append to provider for history
        final provider = context.read<CSVDataProvider>();
        if (provider.hasData) {
          provider.pH.add(pH);
          provider.temperature.add(temperature);
          provider.humidity.add(humidity);
          provider.ec.add(ec);
          provider.n.add(N.toDouble());
          provider.p.add(P.toDouble());
          provider.k.add(K.toDouble());
          provider.timestamps.add(DateTime.now());

          // Keep last 50 samples
          if (provider.timestamps.length > 50) {
            provider.pH.removeAt(0);
            provider.temperature.removeAt(0);
            provider.humidity.removeAt(0);
            provider.ec.removeAt(0);
            provider.n.removeAt(0);
            provider.p.removeAt(0);
            provider.k.removeAt(0);
            provider.timestamps.removeAt(0);
          }
          provider.notifyListeners();
        }
      }
    } catch (_) {}
  }

  // Load default CSV asset
  Future<void> _loadAssetCSV() async {
    try {
      final csvString = await rootBundle.loadString('assets/synthetic_soil_and_plant_data_s2_pattern.csv');
      final parsed = await CSVService.parseCSV(csvString);

      // Check if parsing returned valid data
      if (parsed == null) {
        _showSnackBar("Failed to parse default CSV (parsed = null)");
        return;
      }

      final missing = _checkMissingColumns(parsed);
      if (missing.isNotEmpty) {
        _showSnackBar("Default CSV missing columns: ${missing.join(", ")}");
        return;
      }

      _updateProvider(parsed);

      _showSnackBar(
        "Loaded default CSV with ${parsed["timestamps"]!.length} rows successfully",
      );
    } catch (e) {
      _showSnackBar("Error loading default CSV: $e");
      debugPrint("Default CSV loading error: $e");
    }
  }

  // Pick CSV file
  Future<void> pickCsvFile() async {
    try {
      final parsed = await CSVService.pickCSV();

      if (parsed == null) {
        _showSnackBar("Failed to parse picked CSV (parsed = null)");
        return;
      }

      final missing = _checkMissingColumns(parsed);
      if (missing.isNotEmpty) {
        _showSnackBar("Picked CSV missing columns: ${missing.join(", ")}");
        return;
      }

      _updateProvider(parsed);

      _showSnackBar("Loaded ${parsed["timestamps"]!.length} rows successfully");
    } catch (e) {
      _showSnackBar("Error loading CSV: $e");
      debugPrint("CSV loading error: $e");
    }
  }

  // Helper: normalize keys to lowercase
  Map<String, List<dynamic>> _normalizeKeys(Map<String, List<dynamic>> parsed) {
    final normalized = <String, List<dynamic>>{};
    for (var entry in parsed.entries) {
      normalized[entry.key.toLowerCase()] = entry.value;
    }
    return normalized;
  }

  // Safe provider update
  void _updateProvider(Map<String, List<dynamic>> parsed) {
    try {
      final provider = context.read<CSVDataProvider>();
      final normalized = _normalizeKeys(parsed);

      provider.updateData(
        pH: normalized["ph"]!.cast<double>(),
        temperature: normalized["temperature"]!.cast<double>(),
        humidity: normalized["humidity"]!.cast<double>(),
        ec: normalized["ec"]!.cast<double>(),
        n: normalized["n"]!.cast<double>(),
        p: normalized["p"]!.cast<double>(),
        k: normalized["k"]!.cast<double>(),
        timestamps: normalized["timestamps"]!.cast<DateTime>(),
        latitudes: normalized["latitudes"]!.cast<double>(),
        longitudes: normalized["longitudes"]!.cast<double>(),
        plantStatus: (normalized["plant_status"] ?? const <dynamic>[]) 
            .map((e) => e?.toString() ?? '')
            .toList(),
      );

      _showSnackBar("✅ CSV data loaded successfully!");
    } catch (e) {
      _showSnackBar("❌ Error updating provider:\n$e");
    }
  }

  // Helper: check missing columns with debug
  List<String> _checkMissingColumns(Map<String, List<dynamic>> parsed) {
    final normalized = _normalizeKeys(parsed);

    final requiredCols = [
      "timestamps",
      "ph",
      "temperature",
      "humidity",
      "ec",
      "n",
      "p",
      "k",
      "latitudes",
      "longitudes",
    ];

    final missing = <String>[];
    for (var col in requiredCols) {
      if (!normalized.containsKey(col) || normalized[col] == null || normalized[col]!.isEmpty) {
        missing.add(col);
      }
    }

    // Also grab the available keys for debugging
    final available = normalized.keys.toList();

    if (missing.isNotEmpty) {
      _showSnackBar(
        "⚠️ Missing CSV columns: ${missing.join(", ")}\n"
        "📄 Found columns: ${available.join(", ")}",
      );
    } else {
      _showSnackBar(
        "✅ All required CSV columns found!\n"
        "📄 Found columns: ${available.join(", ")}",
      );
    }

    return missing;
  }

  // Helper: show snackbar
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }


  void _toggleTheme() {
    final current = MyApp.themeNotifier.value;
    MyApp.themeNotifier.value = current == ThemeMode.system
        ? ThemeMode.light
        : current == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.system;
  }

  Icon _themeIcon() {
    final mode = MyApp.themeNotifier.value;
    if (mode == ThemeMode.dark) return const Icon(Icons.dark_mode);
    if (mode == ThemeMode.light) return const Icon(Icons.light_mode);
    return const Icon(Icons.brightness_auto);
  }

  int _currentIndex = 0; // 0: Home, 1: Graph, 2: Heatmap, 3: Robot
  int? _selectedHomeRunIndex; // for averaging health per selected run
  late final PageController _pageController;
  late final TabController _tabController;

  void _showTabSnackBar(int targetIndex) {
    final labels = ['Home', 'Graphs', 'Heatmap', 'Robot'];
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black87 : colors.primary.withOpacity(0.1),
        content: Row(
          children: [
            Text('Go to ${labels[targetIndex]}?', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? colors.primary : colors.primary)),
            const Spacer(),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                setState(() { _currentIndex = targetIndex; });
              },
              child: const Text('Switch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex, keepPage: true);
    _tabController = TabController(length: 4, vsync: this, initialIndex: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CSVDataProvider>(
      builder: (context, provider, _) {
        final pages = <Widget>[
          _buildHome(provider),
          const GraphScreen(embedded: true),
          const HeatmapScreen(embedded: true),
          const RobotControlScreen(embedded: true),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text("🌱 Soil Sensor Dashboard"),
            actions: [
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Choose CSV file',
                onPressed: pickCsvFile,
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: (i) {
                    _pageController.jumpToPage(i);
                    setState(() => _currentIndex = i);
                  },
                  tabs: const [
                    Tab(icon: Icon(Icons.home), text: 'Home'),
                    Tab(icon: Icon(Icons.show_chart), text: 'Graphs'),
                    Tab(icon: Icon(Icons.grid_on), text: 'Heatmap'),
                    Tab(icon: Icon(Icons.smart_toy), text: 'Robot'),
                  ],
                ),
              ),
            ),
          ),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -200) {
                if (_currentIndex < pages.length - 1) {
                  setState(() => _currentIndex++);
                  _tabController.index = _currentIndex;
                  _pageController.animateToPage(
                    _currentIndex,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              } else if (velocity > 200) {
                if (_currentIndex > 0) {
                  setState(() => _currentIndex--);
                  _tabController.index = _currentIndex;
                  _pageController.animateToPage(
                    _currentIndex,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              }
            },
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                _tabController.index = i;
              },
              children: pages,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHome(CSVDataProvider provider) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // Compute last scan range and average soil health per run
    String lastRange = '—';
    double averageHealth = double.nan;
    String healthScope = 'last sample';
    if (provider.hasData) {
      final segments = RunSegmentationService.segmentRuns(
        timestamps: provider.timestamps,
        lats: provider.latitudes,
        lons: provider.longitudes,
      );
      if (segments.isNotEmpty) {
        final last = segments.last;
        lastRange = '${last.startTime.toString().split('.')[0]} → ${last.endTime.toString().split('.')[0]}';
      }

      // Simple health score: normalize a few metrics around ideal ranges (0..1)
      double score(double v, double min, double max) {
        if (!v.isFinite) return 0.0;
        if (v >= min && v <= max) return 1.0;
        final mid = (min + max) / 2.0;
        final half = (max - min) / 2.0;
        final dist = (v - mid).abs();
        return (1.0 - (dist / (half * 2.0))).clamp(0.0, 1.0);
      }

      double avgRange(List<double> series, int s, int e) {
        if (series.isEmpty) return double.nan;
        final int start = s.clamp(0, series.length - 1);
        final int end = e.clamp(start, series.length - 1);
        double sum = 0.0; int count = 0;
        for (int i = start; i <= end; i++) {
          final v = series[i];
          if (v.isFinite) { sum += v; count++; }
        }
        return count == 0 ? double.nan : sum / count;
      }

      if (provider.pH.isNotEmpty) {
        if (_selectedHomeRunIndex != null && segments.isNotEmpty && _selectedHomeRunIndex! >= 0 && _selectedHomeRunIndex! < segments.length) {
          final sel = segments[_selectedHomeRunIndex!];
          final pHAvg = avgRange(provider.pH, sel.startIndex, sel.endIndex);
          final tAvg = avgRange(provider.temperature, sel.startIndex, sel.endIndex);
          final hAvg = avgRange(provider.humidity, sel.startIndex, sel.endIndex);
          final ecAvg = avgRange(provider.ec, sel.startIndex, sel.endIndex);
          final sVals = <double>[
            score(pHAvg, 6.0, 7.5),
            score(tAvg, 20.0, 25.0),
            score(hAvg, 40.0, 60.0),
            score(ecAvg, 1.0, 2.0),
          ].where((v) => v.isFinite).toList();
          if (sVals.isNotEmpty) {
            averageHealth = sVals.reduce((a, b) => a + b) / sVals.length;
            healthScope = 'Run ${_selectedHomeRunIndex! + 1} average';
          }
        } else {
          // Average across all runs (entire dataset)
          final pHAvg = avgRange(provider.pH, 0, provider.pH.length - 1);
          final tAvg = avgRange(provider.temperature, 0, provider.temperature.length - 1);
          final hAvg = avgRange(provider.humidity, 0, provider.humidity.length - 1);
          final ecAvg = avgRange(provider.ec, 0, provider.ec.length - 1);
          final sVals = <double>[
            score(pHAvg, 6.0, 7.5),
            score(tAvg, 20.0, 25.0),
            score(hAvg, 40.0, 60.0),
            score(ecAvg, 1.0, 2.0),
          ].where((v) => v.isFinite).toList();
          if (sVals.isNotEmpty) {
            averageHealth = sVals.reduce((a, b) => a + b) / sVals.length;
            healthScope = 'All runs average';
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SoilHealthCard(message: AlertService.getAlertMessage(pH)),
          const SizedBox(height: 12),
          // Metric widgets grid
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
            ),
            children: [
              MetricTile(label: 'pH', value: pH.toStringAsFixed(2), icon: Icons.science, color: cs.primary),
              MetricTile(label: 'Temperature', value: '${temperature.toStringAsFixed(1)}', unit: '°C', icon: Icons.thermostat, color: Colors.redAccent),
              MetricTile(label: 'Humidity', value: '${humidity.toStringAsFixed(1)}', unit: '%', icon: Icons.water_drop, color: Colors.cyan),
              MetricTile(label: 'EC', value: ec.toStringAsFixed(2), unit: 'mS/cm', icon: Icons.bolt, color: Colors.indigo),
            ],
          ),
          const SizedBox(height: 12),
          GaugesWidget(pH: pH),
          const SizedBox(height: 12),
          NutrientCard(
            N: N,
            P: P,
            K: K,
            plantStatus: (() {
              if (provider.plantStatus.isNotEmpty) {
                return provider.plantStatus.last;
              }
              return '';
            })(),
          ),
          const SizedBox(height: 12),
          // Last scan and averages row
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Time of last scan'),
              subtitle: Text(lastRange),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety),
              title: const Text('Average soil health'),
              subtitle: Text(averageHealth.isFinite ? (averageHealth * 100).toStringAsFixed(0) + '% ($healthScope)' : '—'),
              trailing: TextButton(
                onPressed: () => _openRunPicker(provider),
                child: const Text('Select run'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _suggestionBox(averageHealth),
        ],
      ),
    );
  }

  void _openRunPicker(CSVDataProvider provider) {
    final runs = RunSegmentationService.segmentRuns(
      timestamps: provider.timestamps,
      lats: provider.latitudes,
      lons: provider.longitudes,
    );
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Column(
              children: [
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Select a run', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: runs.length + 1,
                    itemBuilder: (c, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.all_inclusive),
                          title: const Text('All runs'),
                          subtitle: const Text('Use entire dataset'),
                          onTap: () {
                            setState(() { _selectedHomeRunIndex = null; });
                            Navigator.pop(ctx);
                          },
                        );
                      }
                      final idx = i - 1;
                      final r = runs[idx];
                      return ListTile(
                        leading: const Icon(Icons.timeline),
                        title: Text('Run ${idx + 1}'),
                        subtitle: Text('${r.startTime.toString().split('.')[0]} → ${r.endTime.toString().split('.')[0]}'),
                        onTap: () {
                          setState(() { _selectedHomeRunIndex = idx; });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _suggestionBox(double healthScore) {
    String msg;
    IconData icon;
    Color color;
    if (!healthScore.isFinite) {
      msg = 'Load data to see farm health suggestions.';
      icon = Icons.info_outline;
      color = Colors.grey;
    } else if (healthScore >= 0.8) {
      msg = 'Farm health looks great. Maintain current practices.';
      icon = Icons.thumb_up_alt_outlined;
      color = Colors.green;
    } else if (healthScore >= 0.5) {
      msg = 'Moderate health. Consider mild fertilization and watering checks.';
      icon = Icons.tips_and_updates_outlined;
      color = Colors.amber;
    } else {
      msg = 'Low health. Review pH, nutrients, and irrigation urgently.';
      icon = Icons.warning_amber_rounded;
      color = Colors.redAccent;
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: const Text('Farm health summary'),
        subtitle: Text(msg),
      ),
    );
  }
}
