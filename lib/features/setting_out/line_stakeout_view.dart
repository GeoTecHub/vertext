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

class LineStakeoutView extends StatefulWidget {
  const LineStakeoutView({super.key});

  @override
  State<LineStakeoutView> createState() => _LineStakeoutViewState();
}

class _LineStakeoutViewState extends State<LineStakeoutView> {
  late final WebViewController _controller;
  bool _pageReady = false;
  Timer? _tick;

  PointModel? _pointA;
  PointModel? _pointB;
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

      // Pre-select points if available
      if (pointsVM.points.length >= 2) {
        setState(() {
          _pointA = pointsVM.points[0];
          _pointB = pointsVM.points[1];
        });
      } else if (pointsVM.points.isNotEmpty) {
        setState(() {
          _pointA = pointsVM.points[0];
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
    // For line stakeout, "arrival" could mean being very close to the line
    final currentPos = bt.currentPos;
    if (currentPos != null && _pointA != null && _pointB != null) {
      final posA = LatLng(_pointA!.latitude, _pointA!.longitude);
      final posB = LatLng(_pointB!.latitude, _pointB!.longitude);
      
      final distAP = _distanceCalc.as(LengthUnit.Meter, posA, currentPos);
      final bearingAB = _distanceCalc.bearing(posA, posB);
      final bearingAP = _distanceCalc.bearing(posA, currentPos);

      double theta = (bearingAP - bearingAB) * (math.pi / 180.0);
      double offset = distAP * math.sin(theta);

      if (offset.abs() < 0.1) { // 0.1m arrival threshold to the line
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
      
      if (_pointA != null && _pointB != null) {
        await _controller.runJavaScript("if (window.setTargetLine) window.setTargetLine(${_pointA!.latitude}, ${_pointA!.longitude}, ${_pointB!.latitude}, ${_pointB!.longitude});");
        if (p != null) {
          final posA = LatLng(_pointA!.latitude, _pointA!.longitude);
          final posB = LatLng(_pointB!.latitude, _pointB!.longitude);
          
          final distAP = _distanceCalc.as(LengthUnit.Meter, posA, p);
          final bearingAB = _distanceCalc.bearing(posA, posB);
          final bearingAP = _distanceCalc.bearing(posA, p);

          double theta = (bearingAP - bearingAB) * (math.pi / 180.0);
          double offset = distAP * math.sin(theta);
          
          await _controller.runJavaScript("if (window.setTargetLineDistance) window.setTargetLineDistance('Offset: ${offset.abs().toStringAsFixed(3)}m');");
        }
      } else {
        await _controller.runJavaScript("if (window.setTargetLine) window.setTargetLine(null, null, null, null);");
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final btVM = context.watch<BtViewModel>();
    final pointsVM = context.watch<PointsViewModel>();

    PointModel? validPointA;
    PointModel? validPointB;
    if (_pointA != null) {
      for (var p in pointsVM.points) {
        if (p.id == _pointA!.id) {
          validPointA = p;
          break;
        }
      }
    }
    if (_pointB != null) {
      for (var p in pointsVM.points) {
        if (p.id == _pointB!.id) {
          validPointB = p;
          break;
        }
      }
    }

    final currentPos = btVM.currentPos;
    // Use corrected ground mark height for accurate cut/fill
    final groundH = btVM.correctedEllipsoidHeight ?? btVM.currentAlt;

    double? chainage;
    double? offset;
    double? distToB;
    double? deltaHeight;
    String? goLeftRight;
    String? goForwardBackward;

    if (currentPos != null && validPointA != null && validPointB != null) {
      final posA = LatLng(validPointA.latitude, validPointA.longitude);
      final posB = LatLng(validPointB.latitude, validPointB.longitude);

      final distAB = _distanceCalc.as(LengthUnit.Meter, posA, posB);
      final distAP = _distanceCalc.as(LengthUnit.Meter, posA, currentPos);
      final bearingAB = _distanceCalc.bearing(posA, posB);
      final bearingAP = _distanceCalc.bearing(posA, currentPos);

      double theta = (bearingAP - bearingAB) * (math.pi / 180.0);
      chainage = distAP * math.cos(theta);
      offset   = distAP * math.sin(theta);
      distToB  = distAB - chainage;

      goLeftRight       = offset > 0 ? "Go Left"    : "Go Right";
      goForwardBackward = distToB > 0 ? "Go Forward" : "Go Backward";

      if (groundH != null && validPointA.altitude != null && validPointB.altitude != null) {
        final hA   = validPointA.altitude!;
        final hB   = validPointB.altitude!;
        final hProj = hA + (hB - hA) * (chainage / distAB);
        deltaHeight = hProj - groundH;
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

                // Floating tools
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: "layers_line",
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.layers, color: Colors.black),
                        onPressed: () => vm.loadLayers(),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "center_line",
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

          // 4. Line Stakeout Toolbar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Target Point Selection
                Row(
                  children: [
                    const Text("Pt A: ",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Expanded(
                      child: DropdownButtonFormField<PointModel>(
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        value: validPointA,
                        hint: const Text("Point A", style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        items: pointsVM.points.map((p) {
                          return DropdownMenuItem<PointModel>(
                            value: p,
                            child: Text("No: ${p.name}", style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _pointA = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("Pt B: ",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Expanded(
                      child: DropdownButtonFormField<PointModel>(
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        value: validPointB,
                        hint: const Text("Point B", style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        items: pointsVM.points.map((p) {
                          return DropdownMenuItem<PointModel>(
                            value: p,
                            child: Text("No: ${p.name}", style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _pointB = val;
                          });
                        },
                      ),
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
                          _buildInfoCol("Chainage", chainage != null ? "${chainage.toStringAsFixed(3)} m" : "--"),
                          _buildInfoCol("Offset", offset != null ? "${offset.abs().toStringAsFixed(3)} m" : "--"),
                          if (deltaHeight != null)
                            _buildInfoCol(
                              deltaHeight >= 0 ? "Fill ▲" : "Cut ▼",
                              "${deltaHeight.abs().toStringAsFixed(3)} m",
                            ),
                          
                          // Compass Arrow related to the line
                          StreamBuilder<CompassEvent>(
                            stream: FlutterCompass.events,
                            builder: (context, snapshot) {
                              double? heading = snapshot.data?.heading;
                              if (heading == null || validPointA == null || validPointB == null) {
                                return const Icon(Icons.navigation, color: Colors.grey, size: 36);
                              }
                              // Bearing of the line AB
                              final posA = LatLng(validPointA.latitude, validPointA.longitude);
                              final posB = LatLng(validPointB.latitude, validPointB.longitude);
                              double bearingAB = _distanceCalc.bearing(posA, posB);
                              double direction = (bearingAB - heading) * (math.pi / 180);
                              return Transform.rotate(
                                angle: direction,
                                child: const Icon(
                                  Icons.arrow_upward,
                                  size: 36,
                                  color: Colors.blueAccent,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (goLeftRight != null && goForwardBackward != null && offset != null && distToB != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDirectionBadge(
                                goLeftRight,
                                "${offset.abs().toStringAsFixed(3)} m",
                                goLeftRight == "Go Left" ? Icons.arrow_back : Icons.arrow_forward,
                                Colors.redAccent,
                              ),
                              _buildDirectionBadge(
                                goForwardBackward,
                                "${distToB.abs().toStringAsFixed(3)} m",
                                goForwardBackward == "Go Forward" ? Icons.arrow_upward : Icons.arrow_downward,
                                Colors.green,
                              ),
                            ],
                          ),
                        ),
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
