import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../home/home_viewmodel.dart';
import '../bluetooth/bt_viewmodel.dart';
import '../projects/projects_viewmodel.dart';
import '../projects/points_viewmodel.dart';
import '../../core/models/point.dart';
import 'package:vertext_flutter/features/gnss/gnss_live_viewmodel.dart';

import '../home/widgets/home_header.dart';
import '../home/widgets/home_info_bar.dart';
import '../../widgets/hi_tilt_bar.dart';
export '../../widgets/hi_tilt_bar.dart' show HiStatusRow;

class SettingOutView extends StatefulWidget {
  const SettingOutView({super.key});

  @override
  State<SettingOutView> createState() => _SettingOutViewState();
}

class _SettingOutViewState extends State<SettingOutView> {
  late final WebViewController _controller;
  bool _pageReady = false;
  Timer? _tick;

  PointModel? _selectedPoint;
  final Set<String> _pushedPointIds = {};
  final Distance _distanceCalc = const Distance();
  bool _hasArrived = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _pageReady = true;
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

      final bt = context.read<BtViewModel>();
      final gnss = context.read<GnssLiveViewModel>();
      bt.onLine = gnss.updateFromLine;

      final projectsVM = context.read<ProjectsViewModel>();
      final pointsVM = context.read<PointsViewModel>();

      if (projectsVM.selectedProjectId != null) {
        pointsVM.load(projectsVM.selectedProjectId!,
            projectName: projectsVM.selectedProjectName);
      }

      // Pre-select first point if available
      if (pointsVM.points.isNotEmpty) {
        setState(() {
          _selectedPoint = pointsVM.points.first;
        });
      }

      projectsVM.addListener(() {
        if (!mounted) return;
        final newId = projectsVM.selectedProjectId;
        if (newId != null && pointsVM.getProjectId() != newId) {
          pointsVM.load(newId, projectName: projectsVM.selectedProjectName);
        }
      });

      _tick = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (!mounted) return;
        final bt = context.read<BtViewModel>();
        _pushToWeb(bt);
        _checkArrival(bt);
      });
    });
  }

  void _checkArrival(BtViewModel bt) {
    final currentPos = bt.currentPos;
    if (currentPos != null && _selectedPoint != null) {
      final targetPos = LatLng(_selectedPoint!.latitude, _selectedPoint!.longitude);
      final distance = _distanceCalc.as(LengthUnit.Meter, currentPos, targetPos);
      if (distance < 0.5) { // 0.5m arrival threshold
        if (!_hasArrived) {
          _hasArrived = true;
          FlutterRingtonePlayer().playNotification();
        }
      } else {
        _hasArrived = false;
      }
    } else {
      _hasArrived = false;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _pushToWeb(BtViewModel bt) async {
    if (!_pageReady) return;

    final LatLng? p = bt.currentPos;
    final bool receiving = bt.lastRxAt != null &&
        DateTime.now().difference(bt.lastRxAt!).inSeconds <= 3;

    if (mounted) {
      final pointsVM = context.read<PointsViewModel>();
      for (final pt in pointsVM.points) {
        if (pt.id != null && !_pushedPointIds.contains(pt.id!)) {
          _pushedPointIds.add(pt.id!);
          try {
            _controller.runJavaScript(
                "window.addPoint('${pt.id}', ${pt.latitude}, ${pt.longitude}, '${pt.name}', '${pt.code ?? ""}');");
          } catch (_) {}
        }
      }
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
      
      if (_selectedPoint != null) {
        await _controller.runJavaScript("window.setTargetPoint(${_selectedPoint!.latitude}, ${_selectedPoint!.longitude});");
        if (p != null) {
          final targetPos = LatLng(_selectedPoint!.latitude, _selectedPoint!.longitude);
          final dist = _distanceCalc.as(LengthUnit.Meter, p, targetPos);
          await _controller.runJavaScript("window.setTargetDistance('${dist.toStringAsFixed(3)} m');");
        }
      } else {
        await _controller.runJavaScript("window.setTargetPoint(null, null);");
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final btVM = context.watch<BtViewModel>();
    final pointsVM = context.watch<PointsViewModel>();

    PointModel? validSelectedPoint;
    if (_selectedPoint != null) {
      for (var p in pointsVM.points) {
        if (p.id == _selectedPoint!.id) {
          validSelectedPoint = p;
          break;
        }
      }
    }
    if (validSelectedPoint == null && pointsVM.points.isNotEmpty) {
      validSelectedPoint = pointsVM.points.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPoint?.id != validSelectedPoint?.id) {
          setState(() {
            _selectedPoint = validSelectedPoint;
          });
        }
      });
    }

    final currentPos = btVM.currentPos;
    // Use corrected ground mark height for cut/fill; fall back to raw antenna alt
    final groundH = btVM.correctedEllipsoidHeight ?? btVM.currentAlt;

    double? distance;
    double? bearing;
    double? deltaHeight;
    double? deltaNorth;
    double? deltaEast;

    if (currentPos != null && validSelectedPoint != null) {
      final targetPos = LatLng(validSelectedPoint.latitude, validSelectedPoint.longitude);
      distance = _distanceCalc.as(LengthUnit.Meter, currentPos, targetPos);
      bearing = _distanceCalc.bearing(currentPos, targetPos);

      final double bearingRad = bearing * (math.pi / 180.0);
      deltaNorth = distance * math.cos(bearingRad);
      deltaEast  = distance * math.sin(bearingRad);

      if (groundH != null && validSelectedPoint.altitude != null) {
        deltaHeight = validSelectedPoint.altitude! - groundH;
      }
    }

    return Scaffold(
      body: Column(
        children: [
          // 1. Header
          const HomeHeader(),

          // 2. Info Bar
          const HomeInfoBar(),

          // 2b. Tilt + HI bar
          const HiTiltBar(),

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
                          final p = btVM.currentPos;
                          if (p != null && _pageReady) {
                            await _controller.runJavaScript(
                                "window.centerOn(${p.latitude}, ${p.longitude}, 18);");
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Point Stakeout Toolbar (Replaces HomeBottomBar)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Target Point Selection
                Row(
                  children: [
                    const Text("Target: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (pointsVM.points.isEmpty || validSelectedPoint == null) return;
                        int idx = pointsVM.points.indexWhere((p) => p.id == validSelectedPoint!.id);
                        if (idx > 0) {
                          setState(() { _selectedPoint = pointsVM.points[idx - 1]; });
                        }
                      },
                    ),
                    Expanded(
                      child: DropdownButtonFormField<PointModel>(
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: validSelectedPoint,
                        hint: const Text("Select Target Point"),
                        isExpanded: true,
                        items: pointsVM.points.map((p) {
                          return DropdownMenuItem<PointModel>(
                            value: p,
                            child: Text("No: ${p.name} - ${p.code ?? ''}"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPoint = val;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (pointsVM.points.isEmpty || validSelectedPoint == null) return;
                        int idx = pointsVM.points.indexWhere((p) => p.id == validSelectedPoint!.id);
                        if (idx >= 0 && idx < pointsVM.points.length - 1) {
                          setState(() { _selectedPoint = pointsVM.points[idx + 1]; });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Navigation Info
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoCol("Distance", distance != null ? "${distance.toStringAsFixed(3)} m" : "--"),
                          _buildInfoCol("Bearing", bearing != null ? "${bearing.toStringAsFixed(1)}°" : "--"),
                          if (deltaHeight != null)
                            _buildInfoCol(
                              deltaHeight >= 0 ? "Fill ▲" : "Cut ▼",
                              "${deltaHeight.abs().toStringAsFixed(3)} m",
                            ),
                          
                          // Compass Arrow
                          StreamBuilder<CompassEvent>(
                            stream: FlutterCompass.events,
                            builder: (context, snapshot) {
                              double? heading = snapshot.data?.heading;
                              if (heading == null || bearing == null) {
                                return const Icon(Icons.navigation, color: Colors.grey, size: 36);
                              }
                              double direction = (bearing - heading) * (math.pi / 180);
                              return Transform.rotate(
                                angle: direction,
                                child: const Icon(
                                  Icons.navigation,
                                  size: 36,
                                  color: Colors.redAccent,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (deltaNorth != null && deltaEast != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDirectionBadge(
                                deltaNorth > 0 ? "Go North" : "Go South",
                                "${deltaNorth.abs().toStringAsFixed(3)} m",
                                deltaNorth > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                Colors.blue,
                              ),
                              _buildDirectionBadge(
                                deltaEast > 0 ? "Go East" : "Go West",
                                "${deltaEast.abs().toStringAsFixed(3)} m",
                                deltaEast > 0 ? Icons.arrow_forward : Icons.arrow_back,
                                Colors.green,
                              ),
                            ],
                          ),
                        ),
                      // HI status footer
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: HiStatusRow(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionBadge(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

