class PointModel {
  String? id;
  String projectId;
  String name;
  double latitude;
  double longitude;
  double? altitude;
  DateTime timestamp;
  String? solutionType; // e.g. "RTK Fixed", "Float", "Single" (mode_status)
  String? code; // User defined code

  /// Instrument (pole/antenna) height used when the point was measured.
  double? instrumentHeight;

  /// Spatial record id on the server; null until the point has been sent.
  int? serverId;

  // Telemetry
  double? hdop;
  double? pdop;
  double? vdop;
  double? hrms;
  double? vrms;
  double? speed;
  double? heading;
  String? baseId;
  double? diffAge;

  // ── Server metadata (filled from user/spatialdata/project_id=X/) ─────
  int? layerId;
  String? layerName;
  String? doneBy;
  String? spatialUuid;
  DateTime? serverCreated;

  /// SLD99 coordinate stored on the server (ref_coordinate), if any.
  double? refEasting;
  double? refNorthing;

  /// True for points that were collected elsewhere (web / another device)
  /// and only downloaded to this device.
  bool fromServer;

  /// A local edit of a sent point (number / code / HI) that hasn't reached
  /// the server yet. While set, server values don't overwrite the edit.
  bool pendingSync;

  PointModel({
    this.id,
    required this.projectId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
    this.solutionType,
    this.code,
    this.serverId,
    this.instrumentHeight,
    this.hdop,
    this.pdop,
    this.vdop,
    this.hrms,
    this.vrms,
    this.speed,
    this.heading,
    this.baseId,
    this.diffAge,
    this.layerId,
    this.layerName,
    this.doneBy,
    this.spatialUuid,
    this.serverCreated,
    this.refEasting,
    this.refNorthing,
    this.fromServer = false,
    this.pendingSync = false,
  });

  static double? _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String? _str(dynamic v) =>
      (v == null || '$v'.trim().isEmpty) ? null : '$v';

  factory PointModel.fromJson(Map<String, dynamic> json) {
    return PointModel(
      id: json['id']?.toString(),
      projectId: json['projectId'].toString(),
      name: json['name']?.toString() ?? '',
      latitude: _d(json['latitude'])!,
      longitude: _d(json['longitude'])!,
      altitude: _d(json['altitude']),
      timestamp: DateTime.parse(json['timestamp']),
      solutionType: json['solutionType'],
      code: json['code'],
      serverId: (json['serverId'] as num?)?.toInt(),
      instrumentHeight: _d(json['instrumentHeight']),
      hdop: _d(json['hdop']),
      pdop: _d(json['pdop']),
      vdop: _d(json['vdop']),
      hrms: _d(json['hrms']),
      vrms: _d(json['vrms']),
      speed: _d(json['speed']),
      heading: _d(json['heading']),
      baseId: json['baseId'],
      diffAge: _d(json['diffAge']),
      layerId: (json['layerId'] as num?)?.toInt(),
      layerName: json['layerName'],
      doneBy: json['doneBy'],
      spatialUuid: json['spatialUuid'],
      serverCreated: json['serverCreated'] == null
          ? null
          : DateTime.tryParse(json['serverCreated']),
      refEasting: _d(json['refEasting']),
      refNorthing: _d(json['refNorthing']),
      fromServer: json['fromServer'] == true,
      pendingSync: json['pendingSync'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
      'solutionType': solutionType,
      'code': code,
      'serverId': serverId,
      'instrumentHeight': instrumentHeight,
      'hdop': hdop,
      'pdop': pdop,
      'vdop': vdop,
      'hrms': hrms,
      'vrms': vrms,
      'speed': speed,
      'heading': heading,
      'baseId': baseId,
      'diffAge': diffAge,
      'layerId': layerId,
      'layerName': layerName,
      'doneBy': doneBy,
      'spatialUuid': spatialUuid,
      'serverCreated': serverCreated?.toIso8601String(),
      'refEasting': refEasting,
      'refNorthing': refNorthing,
      'fromServer': fromServer,
      'pendingSync': pendingSync,
    };
  }

  /// Builds a point from a GeoJSON feature of user/spatialdata/project_id=X/.
  /// Returns null for non-point features.
  static PointModel? fromServerFeature(
      Map<String, dynamic> f, String projectId) {
    final g = f['geometry'];
    if (g is! Map || '${g['type']}'.toLowerCase() != 'point') return null;
    final c = g['coordinates'];
    if (c is! List || c.length < 2) return null;
    final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    final sid = (f['id'] as num?)?.toInt();
    if (sid == null) return null;

    final created = DateTime.tryParse('${props['date_created'] ?? ''}');
    final p = PointModel(
      id: 'srv-$sid',
      projectId: projectId,
      name: '${props['point_no'] ?? ''}',
      longitude: _d(c[0])!,
      latitude: _d(c[1])!,
      altitude: c.length > 2 ? _d(c[2]) : null,
      timestamp: created ?? DateTime.now(),
      code: _str(props['point_code']),
      serverId: sid,
      fromServer: true,
    );
    p.applyServerProperties(props);
    return p;
  }

  /// Copies server-side metadata onto this point. Measurement values are
  /// only filled where this device has none, so local data wins.
  /// Returns true if anything changed.
  bool applyServerProperties(Map<String, dynamic> props) {
    var changed = false;
    T? upd<T>(T? current, T? server) {
      if (server != null && current != server) changed = true;
      return server ?? current;
    }

    T? fill<T>(T? current, T? server) {
      if (current == null && server != null) {
        changed = true;
        return server;
      }
      return current;
    }

    layerId = upd(layerId, (props['layer_id'] as num?)?.toInt());
    layerName = upd(layerName, _str(props['layer_name']));
    doneBy = upd(doneBy, _str(props['done_by']));
    spatialUuid = upd(spatialUuid, _str(props['spatial_uuid']));
    serverCreated =
        upd(serverCreated, DateTime.tryParse('${props['date_created'] ?? ''}'));

    final ref = props['ref_coordinate'];
    if (ref is Map && ref['coordinates'] is List) {
      final rc = ref['coordinates'] as List;
      if (rc.length >= 2) {
        refEasting = upd(refEasting, _d(rc[0]));
        refNorthing = upd(refNorthing, _d(rc[1]));
      }
    }

    instrumentHeight = fill(instrumentHeight, _d(props['inst_height']));
    solutionType = fill(solutionType, _str(props['mode_status']));
    hdop = fill(hdop, _d(props['hdop']));
    pdop = fill(pdop, _d(props['pdop']));
    vdop = fill(vdop, _d(props['vdop']));
    hrms = fill(hrms, _d(props['hrms']));
    vrms = fill(vrms, _d(props['vrms']));
    if (fromServer) {
      // Server-only points mirror the server exactly.
      code = upd(code, _str(props['point_code']));
    }
    return changed;
  }
}
