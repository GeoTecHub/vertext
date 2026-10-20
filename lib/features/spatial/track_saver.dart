import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';

/// Save the recorded GNSS track as a GeoJSON LineString using a provided callback.
///
/// [saveFeature] should persist the feature to your backend:
///   `(projectId, layerId, geometry, attributes) => Future<void>`
///
/// The callback type is:
///   `Future<void> Function(int, int, Map<String, dynamic>, Map<String, dynamic>)`
Future<void> saveTrackToLayer({
  required BtViewModel bt,
  required int projectId,
  required int layerId,
  required Future<void> Function(
    int projectId,
    int layerId,
    Map<String, dynamic> geometry,
    Map<String, dynamic> attributes,
  ) saveFeature,
}) async {
  if (bt.track.isEmpty) return;

  final feature = bt.toGeoJsonLineString(properties: {
    'source': 'GNSS',
    'recorded_at': DateTime.now().toIso8601String(),
    'points': bt.track.length,
  });

  await saveFeature(
    projectId,
    layerId,
    feature['geometry'] as Map<String, dynamic>,
    feature['properties'] as Map<String, dynamic>,
  );
}
