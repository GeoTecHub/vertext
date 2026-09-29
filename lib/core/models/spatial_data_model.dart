class SpatialRequestItem {
  final SpatialGeometry geometry;
  final SpatialProperties properties;

  /// Optional projected reference coordinate (e.g. SLD99, srid 5235).
  final SpatialGeometry? refCoordinate;

  SpatialRequestItem({
    required this.geometry,
    required this.properties,
    this.refCoordinate,
  });

  Map<String, dynamic> toJson() => {
        'geometry': geometry.toJson(),
        'ref_coordinate': refCoordinate?.toJson(),
        'properties': properties.toJson(),
      };
}

/// Response of POST user/spatialdata/:
/// {"saved_records": [...], "errors": [{"index": 0, "errors": {...}}]}
class SpatialSaveResult {
  final List<Map<String, dynamic>> savedRecords;

  /// Request index -> error messages for that item.
  final Map<int, List<String>> errors;

  SpatialSaveResult({required this.savedRecords, required this.errors});

  factory SpatialSaveResult.fromJson(dynamic j) {
    if (j is List) {
      return SpatialSaveResult(
          savedRecords: j.whereType<Map<String, dynamic>>().toList(),
          errors: {});
    }
    final m = j is Map ? j : const {};
    final errs = <int, List<String>>{};
    for (final e in (m['errors'] as List? ?? const [])) {
      if (e is! Map) continue;
      final idx = (e['index'] as num?)?.toInt() ?? -1;
      errs[idx] = _flatten(e['errors']);
    }
    return SpatialSaveResult(
      savedRecords: (m['saved_records'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      errors: errs,
    );
  }

  static List<String> _flatten(dynamic e) {
    if (e == null) return [];
    if (e is String) return [e];
    if (e is List) return e.expand(_flatten).toList();
    if (e is Map) {
      return e.entries.expand((kv) => kv.key == 'non_field_errors'
          ? _flatten(kv.value)
          : _flatten(kv.value).map((m) => '${kv.key}: $m')).toList();
    }
    return ['$e'];
  }

  /// True when the server rejected the item because its point number is
  /// already used in the project ("... must make a unique set").
  static bool isDuplicate(List<String> msgs) =>
      msgs.any((m) => m.contains('unique set') || m.contains('already exists'));
}

class SpatialGeometry {
  /// GeoJSON type: 'Point', 'LineString' or 'Polygon'.
  final String type;

  /// Point: [x, y, z]; LineString: [[x, y, z], ...];
  /// Polygon: [[[x, y, z], ...]] (closed ring).
  final List<dynamic> coordinates;
  final int srid;

  SpatialGeometry({
    required this.type,
    required this.coordinates,
    this.srid = 4326,
  });

  factory SpatialGeometry.point(double x, double y,
          [double z = 0.0, int srid = 4326]) =>
      SpatialGeometry(type: 'Point', coordinates: [x, y, z], srid: srid);

  factory SpatialGeometry.lineString(List<List<double>> coords,
          {int srid = 4326}) =>
      SpatialGeometry(
          type: 'LineString', coordinates: coords.map(_xyz).toList(), srid: srid);

  /// [ring] is closed automatically if the last vertex differs from the first.
  factory SpatialGeometry.polygon(List<List<double>> ring, {int srid = 4326}) {
    final r = ring.map(_xyz).toList();
    if (r.isNotEmpty &&
        (r.first[0] != r.last[0] || r.first[1] != r.last[1])) {
      r.add(List<double>.from(r.first));
    }
    return SpatialGeometry(type: 'Polygon', coordinates: [r], srid: srid);
  }

  static List<double> _xyz(List<double> c) =>
      c.length >= 3 ? c.sublist(0, 3) : [c[0], c[1], 0.0];

  Map<String, dynamic> toJson() => {
        'type': type,
        'coordinates': coordinates,
        'srid': srid,
      };
}

class SpatialProperties {
  final int projectId;
  final int layerId;
  final dynamic area;
  final int pointNo;
  final String? pointCode;
  final String? instrumentHight;
  final double? hdop;
  final double? pdop;
  final double? vdop;
  final List<dynamic> parentUuid;
  final double? hrms;
  final double? vrms;
  final double? speed;
  final double? heading;
  final String? baseId;
  final double? diffAge;

  /// GNSS solution, e.g. "RTK Fixed" (server field mode_status).
  final String? modeStatus;

  SpatialProperties({
    required this.projectId,
    required this.layerId,
    this.area,
    required this.pointNo,
    this.pointCode,
    this.instrumentHight,
    this.hdop,
    this.pdop,
    this.vdop,
    this.parentUuid = const [],
    this.hrms,
    this.vrms,
    this.speed,
    this.heading,
    this.baseId,
    this.diffAge,
    this.modeStatus,
  });

  // The server stores these as decimals with at most 3 decimal places and
  // rejects anything longer ("Ensure that there are no more than 3 decimal
  // places").
  static double? _r3(double? v) =>
      v == null ? null : double.parse(v.toStringAsFixed(3));

  static String? _dec3(String? v) {
    final d = v == null ? null : double.tryParse(v);
    return d == null ? v : d.toStringAsFixed(3);
  }

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'layer_id': layerId,
        'area': area,
        'point_no': pointNo,
        'point_code': pointCode,
        'instrument_hight': _dec3(instrumentHight), // name in save API docs
        'inst_height': _dec3(instrumentHight), // name the server stores
        'mode_status': modeStatus,
        'hdop': _r3(hdop),
        'pdop': _r3(pdop),
        'vdop': _r3(vdop),
        'parent_uuid': parentUuid,
        // Extra telemetry – not in the documented API, only sent when present.
        if (hrms != null) 'hrms': _r3(hrms),
        if (vrms != null) 'vrms': _r3(vrms),
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (baseId != null) 'base_id': baseId,
        if (diffAge != null) 'diff_age': diffAge,
      };
}
