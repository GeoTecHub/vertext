import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:vertext_flutter/features/spatial/spatial_viewmodel.dart';
import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';

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
  double _zoom = 17;

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
        title: const Text('Spatial Map'),
        actions: [
          IconButton(
            tooltip: 'Center on live',
            icon: const Icon(Icons.my_location),
            onPressed: live == null
                ? null
                : () {
                    _zoom = 18;
                    mapController.move(live, _zoom);
                    setState(() => _followMe = true);
                  },
          ),
          Row(children: [
            const Text('Follow'),
            Switch(value: _followMe, onChanged: (v) => setState(() => _followMe = v)),
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
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          if (spatial.loading) const LinearProgressIndicator(minHeight: 2),

          // Bottom telemetry card (uses .withValues instead of deprecated .withOpacity)
          Positioned(
            left: 8, right: 8, bottom: 8,
            child: Opacity(
              opacity: 0.97,
              child: Card(
                color: Colors.white.withValues(alpha: 0.95), // ✅ updated
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: receiving ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(receiving ? 'Yes' : 'No',
                                    style: const TextStyle(color: Colors.white)),
                              ),
                            ]),
                            Text('Lines: ${bt.lineCount}'),
                            Text('Last RX: ${bt.lastRxAt?.toIso8601String() ?? "—"}'),
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
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('Height: ${bt.currentAlt?.toStringAsFixed(2) ?? "—"}'),
                            Text('HDOP: ${bt.currentHdop?.toStringAsFixed(2) ?? "—"}'),
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
          await context.read<SpatialViewModel>().addPoint(
                projectId: widget.projectId,
                layerId: 1, // pick layer in UI later
                lon: center.longitude,
                lat: center.latitude,
                attrs: {'note': 'added from map'},
              );
        },
        child: const Icon(Icons.add_location),
      ),
    );
  }
}
