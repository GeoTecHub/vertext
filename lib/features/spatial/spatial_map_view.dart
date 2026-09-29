import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:vertext_flutter/features/spatial/spatial_viewmodel.dart';
import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';
import 'package:vertext_flutter/features/projects/points_viewmodel.dart';
import 'package:vertext_flutter/core/models/point.dart';

class SpatialMapView extends StatefulWidget {
  final int projectId;
  const SpatialMapView({super.key, required this.projectId});

  @override
  State<SpatialMapView> createState() => _SpatialMapViewState();
}

class _SpatialMapViewState extends State<SpatialMapView> {
  final mapController = MapController();
  bool _followMe = true;
  bool _centeredOnce = false;
  final double _zoom = 17;

  LatLng? _lastPlotted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SpatialViewModel>().load(widget.projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spatial = context.watch<SpatialViewModel>();
    final bt = context.watch<BtViewModel>();

    // Static feature markers
    final featureMarkers = <Marker>[];
    for (final f in spatial.features) {
      final geom = f['geometry'];
      if (geom?['type'] == 'Point') {
        final c = (geom['coordinates'] as List).cast<num>();
        featureMarkers.add(
          Marker(
            width: 30,
            height: 30,
            point: LatLng(c[1].toDouble(), c[0].toDouble()),
            child: const Icon(Icons.place, size: 28),
          ),
        );
      }
    }

    final live = bt.currentPos;
    final receiving = bt.receiving;

    // Center/follow logic
    if (live != null) {
      final changed = _lastPlotted == null ||
          _lastPlotted!.latitude != live.latitude ||
          _lastPlotted!.longitude != live.longitude;

      if (!_centeredOnce) {
        _centeredOnce = true;
        _lastPlotted = live;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          mapController.move(live, _zoom);
        });
      } else if (_followMe && changed) {
        _lastPlotted = live;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          mapController.move(live, _zoom);
        });
      } else {
        _lastPlotted = live;
      }
    }

    final markers = <Marker>[...featureMarkers];
    if (live != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: live,
          child: const Icon(Icons.radio_button_checked, size: 34),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Data Viewer'),
        actions: [
          Row(children: [
            const Text('Follow'),
            Switch(
                value: _followMe,
                onChanged: (v) => setState(() => _followMe = v)),
            const SizedBox(width: 8),
          ]),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: live ?? const LatLng(7.8731, 80.7718),
              initialZoom: live != null ? _zoom : 7,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          if (spatial.loading) const LinearProgressIndicator(minHeight: 2),

          // Bottom telemetry card (uses .withValues instead of deprecated .withOpacity)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Opacity(
              opacity: 0.97,
              child: Card(
                color: Colors.white.withValues(alpha: 0.95),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('Receiving: '),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: receiving ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(receiving ? 'Yes' : 'No',
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                            ]),
                            Text('Lines: ${bt.lineCount}'),
                            Text(
                                'Last RX: ${bt.lastRxAt?.toIso8601String() ?? "—"}'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Lat/Lon: ${live != null ? "${live.latitude.toStringAsFixed(7)}, ${live.longitude.toStringAsFixed(7)}" : "—"}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                                'Height: ${bt.currentAlt?.toStringAsFixed(2) ?? "—"}'),
                            Text(
                                'HDOP: ${bt.currentHdop?.toStringAsFixed(2) ?? "—"}'),
                            Text('Solution: ${bt.currentSolution ?? "—"}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final center = mapController.camera.center;
          // Use BT location if available and following, otherwise center
          // Actually user likely wants to capture CURRENT BT POS if available, else Map Center.
          // Existing logic was using mapController center.
          // Let's stick to map center but if followed, it is the BT pos.

          final pVM = context.read<PointsViewModel>();
          final bt = context.read<BtViewModel>();

          final nextName = pVM.getNextPointNumber();

          final point = PointModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
            projectId: widget.projectId.toString(),
            name: nextName,
            latitude: center.latitude,
            longitude: center.longitude,
            altitude: bt.currentAlt,
            timestamp: DateTime.now(),
            solutionType: bt.currentSolution,
            code: '', // Empty code initially
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

          await pVM.addPoint(point);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Point No: $nextName saved locally')),
            );
          }
        },
        child: const Icon(Icons.add_location),
      ),
    );
  }
}
