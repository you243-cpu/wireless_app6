// lib/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/line_chart.dart';
import '../widgets/multi_line_chart.dart';
import '../providers/csv_data_provider.dart';
import '../services/heatmap_service.dart';
import '../widgets/plant_status_legend.dart';
import '../services/run_segmentation.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  // Start more zoomed-in by default to avoid clutter.
  double zoomLevel = 3;
  int scrollIndex = 0;
  int _dataLength = 0; // number of x-points (runs)
  Set<int> _selectedFarmIds = <int>{};

  void zoomIn() => setState(() { if (zoomLevel < 5) zoomLevel += 1; });
  void zoomOut() => setState(() { if (zoomLevel > 1) zoomLevel -= 1; });
  void scrollLeft() => setState(() { if (scrollIndex > 0) scrollIndex--; });
  void scrollRight() {
    if (scrollIndex < _dataLength - 10) scrollIndex++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CSVDataProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabLabelColor = isDark ? Colors.tealAccent : Colors.green;
    final unselectedTabColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final iconColor = isDark ? Colors.tealAccent : Colors.black87;

    if (!provider.hasData) {
      return const Scaffold(
        body: Center(child: Text("No data available.")),
      );
    }

    // Compute run segmentation and per-run averages
    final segments = RunSegmentationService.segmentRuns(
      timestamps: provider.timestamps,
      lats: provider.latitudes,
      lons: provider.longitudes,
    );
    final summaries = RunSegmentationService.summarizeRuns(provider: provider, segments: segments);
    final runTimestamps = segments.map((s) => s.startTime).toList();
    _dataLength = runTimestamps.length;

    // Helper to average a raw series per segmented run
    List<double> perRunAvgForSeries(List<double> series) {
      final List<double> out = [];
      for (final seg in segments) {
        double sum = 0.0;
        int count = 0;
        final int s = seg.startIndex;
        final int e = seg.endIndex;
        for (int i = s; i <= e && i < series.length; i++) {
          final v = series[i];
          if (v.isFinite) { sum += v; count++; }
        }
        out.add(count == 0 ? double.nan : (sum / count));
      }
      return out;
    }

    // Precompute Plant Status per-run for all runs (used in both filtered and unfiltered paths)
    final List<double> _encodedStatusSeries = List<double>.generate(
      provider.timestamps.length,
      (i) => i < provider.plantStatus.length ? encodePlantStatus(provider.plantStatus[i]).toDouble() : double.nan,
    );
    final List<double> _statusPerRunAll = perRunAvgForSeries(_encodedStatusSeries);

    // Farm clustering to enable filtering
    final assignment = RunSegmentationService.assignFarms(
      runs: segments,
      lats: provider.latitudes,
      lons: provider.longitudes,
    );
    final farms = assignment.farms;
    final runsWithFarms = assignment.runs;

    // Build farm filter UI row
    Widget farmFilters() {
      if (farms.isEmpty) return const SizedBox.shrink();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: const Text('All Farms'),
                selected: _selectedFarmIds.length == farms.length,
                onSelected: (sel) {
                  setState(() {
                    if (_selectedFarmIds.length == farms.length) {
                      _selectedFarmIds.clear();
                    } else {
                      _selectedFarmIds = farms.map((f) => f.id).toSet();
                    }
                  });
                },
              ),
            ),
            ...farms.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onLongPress: () => setState(() { _selectedFarmIds = {f.id}; }),
                    child: FilterChip(
                      label: Text('Farm ${f.id}')
                    ,
                      selected: _selectedFarmIds.contains(f.id),
                      onSelected: (sel) {
                        setState(() {
                          if (_selectedFarmIds.contains(f.id)) {
                            _selectedFarmIds.remove(f.id);
                          } else {
                            _selectedFarmIds.add(f.id);
                          }
                        });
                      },
                    ),
                  ),
                )),
          ],
        ),
      );
    }

    // Filter by selected farms if any
    List<int> allowedFarmIds = _selectedFarmIds.isEmpty ? farms.map((f) => f.id).toList() : _selectedFarmIds.toList();
    List<int> allowedRunIndices = [
      for (int i = 0; i < runsWithFarms.length; i++)
        if ((runsWithFarms[i].farmId != null) && allowedFarmIds.contains(runsWithFarms[i].farmId)) i
    ];
    if (allowedRunIndices.isNotEmpty && allowedRunIndices.length != runsWithFarms.length) {
      // Create filtered per-run arrays preserving order
      List<DateTime> filteredTimestamps = [ for (final i in allowedRunIndices) runTimestamps[i] ];
      List<double> filterSeries(List<double> s) => [ for (final i in allowedRunIndices) (i < s.length ? s[i] : double.nan) ];
      final pHPerRunFull = RunSegmentationService.averagesForMetric(summaries, 'pH');
      final nPerRunFull = RunSegmentationService.averagesForMetric(summaries, 'N');
      final pPerRunFull = RunSegmentationService.averagesForMetric(summaries, 'P');
      final kPerRunFull = RunSegmentationService.averagesForMetric(summaries, 'K');
      final temperaturePerRunFull = RunSegmentationService.averagesForMetric(summaries, 'Temperature');
      final humidityPerRunFull = RunSegmentationService.averagesForMetric(summaries, 'Humidity');
      final ecPerRunFull = RunSegmentationService.averagesForMetric(summaries, 'EC');
      final statusPerRunFull = _statusPerRunAll;

      final pHPerRun = filterSeries(pHPerRunFull);
      final nPerRun = filterSeries(nPerRunFull);
      final pPerRun = filterSeries(pPerRunFull);
      final kPerRun = filterSeries(kPerRunFull);
      final temperaturePerRun = filterSeries(temperaturePerRunFull);
      final humidityPerRun = filterSeries(humidityPerRunFull);
      final ecPerRun = filterSeries(ecPerRunFull);
      final statusPerRun = filterSeries(statusPerRunFull);

      _dataLength = filteredTimestamps.length;
      return Scaffold(
        appBar: AppBar(
          title: const Text("📊 Graphs"),
          backgroundColor: isDark ? Colors.black : Colors.green[100],
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: zoomIn, icon: Icon(Icons.zoom_in, color: iconColor)),
                IconButton(onPressed: zoomOut, icon: Icon(Icons.zoom_out, color: iconColor)),
                IconButton(onPressed: scrollLeft, icon: Icon(Icons.arrow_left, color: iconColor)),
                IconButton(onPressed: scrollRight, icon: Icon(Icons.arrow_right, color: iconColor)),
              ],
            ),
            farmFilters(),
            Expanded(
              child: DefaultTabController(
                length: 9,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      labelColor: tabLabelColor,
                      unselectedLabelColor: unselectedTabColor,
                      indicatorColor: tabLabelColor,
                      tabs: const [
                        Tab(text: "pH"),
                        Tab(text: "N"),
                        Tab(text: "P"),
                        Tab(text: "K"),
                        Tab(text: "Temperature"),
                        Tab(text: "Humidity"),
                        Tab(text: "EC"),
                        Tab(text: "Plant Status"),
                        Tab(text: "All"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          LineChartWidget(data: pHPerRun, color: Colors.green, label: "pH", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          LineChartWidget(data: nPerRun, color: Colors.blue, label: "N", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          LineChartWidget(data: pPerRun, color: Colors.orange, label: "P", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          LineChartWidget(data: kPerRun, color: Colors.purple, label: "K", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          LineChartWidget(data: temperaturePerRun, color: Colors.red, label: "Temperature", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          LineChartWidget(data: humidityPerRun, color: Colors.cyan, label: "Humidity", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          LineChartWidget(data: ecPerRun, color: Colors.indigo, label: "EC", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                          Column(children: [
                            const SizedBox(height: 8),
                            const PlantStatusLegend(axis: Axis.horizontal, isDense: true, numericOnly: false),
                            Expanded(child: LineChartWidget(data: statusPerRun, color: Colors.teal, label: "Plant Status (count or No Turmeric)", timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex)),
                          ]),
                          MultiLineChartWidget(pHData: pHPerRun, nData: nPerRun, pData: pPerRun, kData: kPerRun, temperatureData: temperaturePerRun, humidityData: humidityPerRun, ecData: ecPerRun, timestamps: filteredTimestamps, zoomLevel: zoomLevel, scrollIndex: scrollIndex),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Build per-run average series for each metric
    final pHPerRun = RunSegmentationService.averagesForMetric(summaries, 'pH');
    final nPerRun = RunSegmentationService.averagesForMetric(summaries, 'N');
    final pPerRun = RunSegmentationService.averagesForMetric(summaries, 'P');
    final kPerRun = RunSegmentationService.averagesForMetric(summaries, 'K');
    final temperaturePerRun = RunSegmentationService.averagesForMetric(summaries, 'Temperature');
    final humidityPerRun = RunSegmentationService.averagesForMetric(summaries, 'Humidity');
    final ecPerRun = RunSegmentationService.averagesForMetric(summaries, 'EC');

    // Plant status encoded and averaged per run
    final statusPerRun = _statusPerRunAll;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Graphs"),
        backgroundColor: isDark ? Colors.black : Colors.green[100],
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: zoomIn, icon: Icon(Icons.zoom_in, color: iconColor)),
              IconButton(onPressed: zoomOut, icon: Icon(Icons.zoom_out, color: iconColor)),
              IconButton(onPressed: scrollLeft, icon: Icon(Icons.arrow_left, color: iconColor)),
              IconButton(onPressed: scrollRight, icon: Icon(Icons.arrow_right, color: iconColor)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              'Showing per-run averages',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 9,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: tabLabelColor,
                    unselectedLabelColor: unselectedTabColor,
                    indicatorColor: tabLabelColor,
                    tabs: const [
                      Tab(text: "pH"),
                      Tab(text: "N"),
                      Tab(text: "P"),
                      Tab(text: "K"),
                      Tab(text: "Temperature"),
                      Tab(text: "Humidity"),
                      Tab(text: "EC"),
                      Tab(text: "Plant Status"),
                      Tab(text: "All"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        LineChartWidget(
                          data: pHPerRun,
                          color: Colors.green,
                          label: "pH",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: nPerRun,
                          color: Colors.blue,
                          label: "N",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: pPerRun,
                          color: Colors.orange,
                          label: "P",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: kPerRun,
                          color: Colors.purple,
                          label: "K",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: temperaturePerRun,
                          color: Colors.red,
                          label: "Temperature",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: humidityPerRun,
                          color: Colors.cyan,
                          label: "Humidity",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        LineChartWidget(
                          data: ecPerRun,
                          color: Colors.indigo,
                          label: "EC",
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                        // Plant Status: numeric code line + categorical legend
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            const PlantStatusLegend(axis: Axis.horizontal, isDense: true, numericOnly: false),
                            Expanded(
                              child: LineChartWidget(
                                data: statusPerRun,
                                color: Colors.teal,
                                label: "Plant Status (count or No Turmeric)",
                                timestamps: runTimestamps,
                                zoomLevel: zoomLevel,
                                scrollIndex: scrollIndex,
                              ),
                            ),
                          ],
                        ),
                        MultiLineChartWidget(
                          pHData: pHPerRun,
                          nData: nPerRun,
                          pData: pPerRun,
                          kData: kPerRun,
                          temperatureData: temperaturePerRun,
                          humidityData: humidityPerRun,
                          ecData: ecPerRun,
                          timestamps: runTimestamps,
                          zoomLevel: zoomLevel,
                          scrollIndex: scrollIndex,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
