import '../models/spatial_data_model.dart';
import '../api/api_service.dart';

class SpatialRepository {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> listByProject(int projectId) =>
      _api.getSpatialByProject(projectId);

  Future<List<Map<String, dynamic>>> listAll() => _api.getAllSpatial();

  Future<Map<String, dynamic>> create({
    required int projectId,
    required int layerId,
    required Map<String, dynamic> geometry,
    Map<String, dynamic> properties = const {},
  }) =>
      _api.createSpatial(
        projectId: projectId,
        layerId: layerId,
        geometry: geometry,
        properties: properties,
      );

  Future<Map<String, dynamic>> update(
    int id, {
    Map<String, dynamic>? geometry,
    Map<String, dynamic>? properties,
  }) =>
      _api.updateSpatial(id, geometry: geometry, properties: properties);

  Future<void> delete(int id) => _api.deleteSpatial(id);

  Future<void> deleteMany(List<int> ids) => _api.deleteSpatialBulk(ids);

  Future<SpatialSaveResult> sendBatch(List<SpatialRequestItem> items) =>
      _api.sendSpatialData(items);

  Future<int> maxPoint(int projectId) => _api.getMaxPoint(projectId);

  /// Server record id of a feature from the list endpoints. Works for flat
  /// rows and for GeoJSON features (id at top level or in properties).
  static int? featureId(Map<String, dynamic> f) =>
      _intOf(f, const ['id', 'spatial_id', 'spatialdata_id', 'gid']);

  static int? featurePointNo(Map<String, dynamic> f) =>
      _intOf(f, const ['point_no']);

  /// [lon, lat] of a Point feature, from GeoJSON coordinates or a WKT/EWKT
  /// string such as "SRID=4326;POINT Z (80.1 6.8 0)". Null if not a point
  /// or not parseable.
  static List<double>? featureLonLat(Map<String, dynamic> f) {
    final g = f['geometry'] ?? f['geom'];
    if (g is Map) {
      final type = '${g['type'] ?? 'Point'}'.toLowerCase();
      final c = g['coordinates'];
      if (type == 'point' && c is List && c.length >= 2) {
        return [(c[0] as num).toDouble(), (c[1] as num).toDouble()];
      }
      return null;
    }
    if (g is String) {
      final m = RegExp(r'POINT\s*Z?\s*\(\s*([-\d.eE]+)\s+([-\d.eE]+)',
              caseSensitive: false)
          .firstMatch(g);
      if (m != null) {
        return [double.parse(m.group(1)!), double.parse(m.group(2)!)];
      }
    }
    return null;
  }

  static int? _intOf(Map<String, dynamic> f, List<String> keys) {
    final props = f['properties'];
    for (final src in [f, if (props is Map) props]) {
      for (final k in keys) {
        final v = src[k];
        if (v is num) return v.toInt();
        if (v is String && int.tryParse(v) != null) return int.parse(v);
      }
    }
    return null;
  }
}
