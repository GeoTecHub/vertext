import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';

import 'home_viewmodel.dart';
import '../../features/bluetooth/bt_viewmodel.dart';

import '../../features/projects/projects_viewmodel.dart';
import '../../features/projects/points_viewmodel.dart';
import '../../features/projects/point_details_card.dart';
import '../../core/models/point.dart';
import 'package:vertext_flutter/features/gnss/gnss_live_viewmodel.dart';
import '../../features/home/tolerance_viewmodel.dart';

// New Widgets
import 'widgets/home_header.dart';
import 'widgets/home_info_bar.dart';
import 'widgets/bottom_toolbar.dart';

class SurveyView extends StatefulWidget {
  const SurveyView({super.key});

  @override
  State<SurveyView> createState() => _SurveyViewState();
}

class _SurveyViewState extends State<SurveyView> {
  late final WebViewController _controller;
  bool _pageReady = false;
  Timer? _tick;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ProjectsViewModel? _projectsVmRef;
  VoidCallback? _projectsListener;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Tapping a saved point on the map opens its details.
      ..addJavaScriptChannel('PointTap', onMessageReceived: (msg) {
        if (!mounted) return;
        final pt = context
            .read<PointsViewModel>()
            .points
            .where((p) => p.id == msg.message)
            .firstOrNull;
        if (pt != null) showPointDetails(context, pt);
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _pageReady = true;
            // ⚠️ Do not await before using context — avoids use_build_context_synchronously
            _controller.runJavaScript("window.setFollowMe(true);");
            if (!mounted) return;
            final bt = context.read<BtViewModel>();
            _pushToWeb(bt);
          },
        ),
      )
      ..loadFlutterAsset('assets/map.html');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadLayers();

      // Wire Bluetooth data directly to GnssLiveViewModel for parsing
      final bt = context.read<BtViewModel>();
      final gnss = context.read<GnssLiveViewModel>();
      bt.onLine = gnss.updateFromLine;

      // Load points if project is selected & Setup Sync
      final projectsVM = context.read<ProjectsViewModel>();
      final pointsVM = context.read<PointsViewModel>();

      // Initial Load
      if (projectsVM.selectedProjectId != null) {
        pointsVM.load(projectsVM.selectedProjectId!,
            projectName: projectsVM.selectedProjectName);
      }

      // Sync Listener: Reload points when project selection changes
      _projectsVmRef = projectsVM;
      _projectsListener = () {
        if (!mounted) return;
        final newId = projectsVM.selectedProjectId;
        if (newId != null && pointsVM.getProjectId() != newId) {
          pointsVM.load(newId, projectName: projectsVM.selectedProjectName);
        }
      };
      projectsVM.addListener(_projectsListener!);

      _tick = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (!mounted) return;
        _pushToWeb(bt);
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (_projectsListener != null) {
      _projectsVmRef?.removeListener(_projectsListener!);
    }
    super.dispose();
  }

  Future<void> _pushToWeb(BtViewModel bt) async {
    if (!_pageReady) return;

    final LatLng? p = bt.currentPos;
    final bool receiving = bt.lastRxAt != null &&
        DateTime.now().difference(bt.lastRxAt!).inSeconds <= 3;

    // Push existing points to map
    if (mounted) {
      final pointsVM = context.read<PointsViewModel>();
      for (final pt in pointsVM.points) {
        try {
          // Use a key or ID check in JS ideally, here we just push
          // Passing Name AND Code
          _controller.runJavaScript(
              "window.addPoint('${pt.id}', ${pt.latitude}, ${pt.longitude}, '${pt.name}', '${pt.code ?? ""}');");
        } catch (_) {}
      }
      // Drop markers of deleted points.
      final ids = pointsVM.points.map((e) => "'${e.id}'").join(',');
      _controller.runJavaScript(
          "if (window.keepPoints) window.keepPoints([$ids]);");
    }

    final String js = """
      window.updateLive(
        ${p != null ? p.latitude.toStringAsFixed(9) : "null"},
        ${p != null ? p.longitude.toStringAsFixed(9) : "null"},
        ${bt.currentAlt != null ? bt.currentAlt!.toStringAsFixed(3) : "null"},
        ${bt.currentSolution != null ? "'${bt.currentSolution}'" : "null"},
        ${receiving ? "true" : "false"}
      );
    """;

    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  // Toggle Map/Plane
  void setMapType(bool isPlane) {
    if (!_pageReady) return;
    final type = isPlane ? 'plane' : 'standard';
    _controller.runJavaScript("window.setMapType('$type');");
  }

  // ... inside _HomeViewState ...

  Future<void> _savePoint(String name, String code) async {
    final bt = context.read<BtViewModel>();
    final projectsVM = context.read<ProjectsViewModel>();

    if (projectsVM.selectedProjectId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No project selected!")));
      return;
    }

    if (bt.currentPos == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No GPS position!")));
      return;
    }

    // --- Point number check (device + fresh server check) ---
    final pointsVM = context.read<PointsViewModel>();
    if (name.trim().isEmpty) name = pointsVM.getNextPointNumber();
    final status = await pointsVM.verifyPointNumber(name);
    if (!mounted) return;
    if (status.isTaken) {
      final next = pointsVM.getNextPointNumber();
      final use = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Point No $name is taken"),
          content: Text("${status.label}.\n\nSave as point $next instead?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel")),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text("Use $next")),
          ],
        ),
      );
      if (use != true || !mounted) return;
      name = next;
    }

    final p = bt.currentPos!;
    final alt = bt.currentAlt;
    final sol = bt.currentSolution ?? "Single";

    // --- Quality Check ---
    final tol = context.read<ToleranceViewModel>();
    // We treat "Single" as "SINGLE" etc to match.
    // Usually bt.currentSolution is uppercase.
    final passed = tol.checkQuality(
      currentSol: sol.toUpperCase(),
      currentHrms: bt.currentHrms,
      currentVrms: bt.currentVrms,
      currentPdop: bt.currentPdop,
      currentAge: bt.currentDiffAge,
    );

    if (!passed) {
      // Show Alert Dialog
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text("Poor Quality"),
                content: Text(
                    "Current solution does not meet tolerance settings.\n\n"
                    "Required: ${tol.solution}\n"
                    "Current: $sol\n"
                    "HRMS: ${bt.currentHrms} / ${tol.hrms}\n"
                    "PDOP: ${bt.currentPdop} / ${tol.pdop}"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _proceedSave(name, code, p, alt, sol, bt);
                      },
                      child: const Text("Save Anyway")),
                ],
              ));
      return;
    }

    _proceedSave(name, code, p, alt, sol, bt);
  }

  Future<void> _proceedSave(String name, String code, LatLng p, double? alt,
      String sol, BtViewModel bt) async {
    final projectsVM = context.read<ProjectsViewModel>();
    final pointsVM = context.read<PointsViewModel>();
    final tol = context.read<ToleranceViewModel>();

    // Check if averaging is needed
    final avgCount = tol.averagePoints;
    if (avgCount > 1) {
      // Collect multiple samples
      final avgResult = await _collectAveragedPoint(avgCount, bt);
      if (avgResult == null) return; // User cancelled

      p = avgResult['position'];
      alt = avgResult['altitude'];
    }

    // Use provided name/code
    final newPoint = PointModel(
      projectId: projectsVM.selectedProjectId!,
      name: name.isNotEmpty ? name : pointsVM.getNextPointNumber(),
      code: code,
      latitude: p.latitude,
      longitude: p.longitude,
      altitude: alt,
      timestamp: DateTime.now(),
      solutionType: sol,
      hdop: bt.currentHdop,
      pdop: bt.currentPdop,
      vdop: bt.currentVdop,
      hrms: bt.currentHrms,
      vrms: bt.currentVrms,
      speed: bt.currentSpeed,
      heading: bt.currentHeading,
      baseId: bt.currentBaseId,
      diffAge: bt.currentDiffAge,
      instrumentHeight: bt.correctedHI,
    );

    await pointsVM.addPoint(newPoint);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Point No: ${newPoint.name} saved!")),
      );
      // Also visualize on map
      _controller.runJavaScript("""
       window.addPoint(
         '${newPoint.id}', 
         ${newPoint.latitude}, 
         ${newPoint.longitude}, 
         '${newPoint.name}',
         '${newPoint.code ?? ""}'
       );
     """);
    }
  }

  Future<Map<String, dynamic>?> _collectAveragedPoint(
      int count, BtViewModel bt) async {
    final ValueNotifier<int> collectedCount = ValueNotifier(0);
    final List<LatLng> positions = [];
    final List<double> altitudes = [];
    bool cancelled = false;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: collectedCount,
        builder: (context, value, _) => AlertDialog(
          title: const Text("Averaging Position"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Keep receiver steady"),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: value / count),
              const SizedBox(height: 8),
              Text("Collected: $value / $count epochs"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );

    // Collect samples
    DateTime? lastSampleTime;
    while (positions.length < count && !cancelled) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (cancelled) break;

      // Only collect if we have a new position (check lastRxAt changed)
      if (bt.currentPos != null && bt.lastRxAt != lastSampleTime) {
        positions.add(bt.currentPos!);
        if (bt.currentAlt != null) {
          altitudes.add(bt.currentAlt!);
        }
        lastSampleTime = bt.lastRxAt;
        collectedCount.value = positions.length;
      }
    }

    if (mounted && !cancelled) {
      Navigator.pop(context);
    }

    if (cancelled || positions.isEmpty) {
      return null;
    }

    // Calculate averages
    double avgLat = positions.map((p) => p.latitude).reduce((a, b) => a + b) /
        positions.length;
    double avgLon = positions.map((p) => p.longitude).reduce((a, b) => a + b) /
        positions.length;
    double? avgAlt;
    if (altitudes.isNotEmpty) {
      avgAlt = altitudes.reduce((a, b) => a + b) / altitudes.length;
    }

    return {
      'position': LatLng(avgLat, avgLon),
      'altitude': avgAlt,
    };
  }

  @override
  Widget build(BuildContext context) {
    // We don't need to watch everything here, widgets handle themselves
    // except for map-specific overlays if needed.
    final vm = context.watch<HomeViewModel>();

    return Scaffold(
      key: _scaffoldKey,
      // drawer: const AppDrawer(), // Removed for tab integration
      body: Column(
        children: [
          // 1. Header
          const HomeHeader(),

          // 2. Info Bar
          const HomeInfoBar(),

          // 3. Map Area (Expanded)
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (vm.loading) const LinearProgressIndicator(minHeight: 2),

                // Floating tools (Layers, Center)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: "layers",
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.layers, color: Colors.black),
                        onPressed: () => vm.loadLayers(),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "center",
                        backgroundColor:
                            const Color.fromARGB(255, 126, 223, 15),
                        child:
                            const Icon(Icons.my_location, color: Colors.white),
                        onPressed: () async {
                          final bt = context.read<BtViewModel>();
                          final p = bt.currentPos;
                          if (p != null && _pageReady) {
                            await _controller.runJavaScript(
                                "window.centerOn(${p.latitude}, ${p.longitude}, 18);");
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Compass
                Positioned(
                  top: 10,
                  right: 10,
                  child: StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (context, snapshot) {
                      double? direction = snapshot.data?.heading;

                      final angle = direction == null
                          ? 0.0
                          : (direction * (math.pi / 180) * -1);

                      return Transform.rotate(
                        angle: angle,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.white70, shape: BoxShape.circle),
                          child: const Icon(Icons.explore,
                              size: 40, color: Colors.blueAccent),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Toolbar
          HomeBottomBar(
            onSave: _savePoint,
            onToggleView: setMapType, // Pass the toggle function
          ),
        ],
      ),
    );
  }
}
