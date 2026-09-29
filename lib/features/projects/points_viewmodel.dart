import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_service.dart';
import '../../core/models/point.dart';
import '../../core/models/spatial_data_model.dart';
import '../../core/repository/point_repository.dart';
import '../../core/repository/spatial_repository.dart';
import '../../core/services/local_storage_service.dart';
import '../bluetooth/bt_viewmodel.dart';
import '../../utils/sld99_converter.dart';

class PointsViewModel extends ChangeNotifier {
  final _repo = PointRepository();
  bool loading = false;
  List<PointModel> points = [];
  String? _projectId;
  String? getProjectId() => _projectId;

  String? _projectName;

  /// Highest point number already stored on the server for this project.
  int _serverMaxPoint = 0;

  /// Point numbers used on the server for this project (refreshed live).
  final Set<int> _serverNumbers = {};

  /// When the server numbers were last refreshed; null = never / offline.
  DateTime? serverCheckedAt;
  bool serverReachable = false;

  Timer? _poll;
  static const _pollInterval = Duration(seconds: 20);

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> load(String projectId, {String? projectName}) async {
    if (_projectId != projectId) {
      _serverMaxPoint = 0;
      _serverNumbers.clear();
      serverCheckedAt = null;
      serverReachable = false;
    }
    _projectId = projectId;
    if (projectName != null) _projectName = projectName;

    loading = true;
    notifyListeners();

    try {
      // 1. Load from Repo (SharedPrefs)
      var repoPoints = <PointModel>[];
      try {
        repoPoints = await _repo.list(projectId);
      } catch (e) {
        if (kDebugMode) print('Load points (prefs) failed: $e');
      }

      // 2. Merge points from the project's local file, if the name is known.
      // A storage/permission error here must not block the list.
      if (_projectName != null) {
        try {
          final localPoints =
              await LocalStorageService().loadPoints(_projectName!);
          for (final lp in localPoints) {
            if (!repoPoints.any((rp) => rp.id == lp.id)) repoPoints.add(lp);
          }
        } catch (e) {
          if (kDebugMode) print('Load points (file) failed: $e');
        }
      }
      points = repoPoints;
      _sortPoints();
    } finally {
      loading = false;
      notifyListeners();
    }

    refreshServerNumbers();
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => refreshServerNumbers());
  }

  /// Re-reads which point numbers exist on the server (so numbers taken by
  /// other devices show up), links local points to server records, and
  /// updates the next suggested number.
  Future<void> refreshServerNumbers() async {
    final projectId = _projectId;
    final id = int.tryParse(projectId ?? '');
    if (id == null) return;
    try {
      await _retryPendingUpdates();
      final features = await _spatialRepo.listByProject(id);
      if (_projectId != projectId) return;
      _serverNumbers
        ..clear()
        ..addAll(features.map(SpatialRepository.featurePointNo).whereType<int>());
      await _matchServer(features);
      await _mergeServerPoints(features, projectId!);
      serverReachable = true;
      serverCheckedAt = DateTime.now();
    } catch (_) {
      serverReachable = false;
    }
    await _syncServerMaxPoint(projectId!);
    notifyListeners();
  }

  /// Matches unsent local points against server [features] by point number.
  /// Same number and same position (or position unknown) -> linked as
  /// already on the server. Same number, different position -> conflict.
  /// Also raises the known server max point number. Returns the local ids
  /// of conflicting points.
  Future<Set<String>> _matchServer(List<Map<String, dynamic>> features) async {
    const tol = 1e-6; // degrees, about 0.1 m
    final byNo = <int, List<Map<String, dynamic>>>{};
    for (final f in features) {
      final no = SpatialRepository.featurePointNo(f);
      if (no == null) continue;
      byNo.putIfAbsent(no, () => []).add(f);
      _serverNumbers.add(no);
      if (no > _serverMaxPoint) _serverMaxPoint = no;
    }
    final taken = points.map((p) => p.serverId).whereType<int>().toSet();
    final conflicts = <String>{};
    for (final p in points) {
      if (p.serverId != null) continue;
      final candidates = byNo[int.tryParse(p.name)];
      if (candidates == null) continue;
      Map<String, dynamic>? match;
      for (final f in candidates) {
        final sid = SpatialRepository.featureId(f);
        if (sid == null || taken.contains(sid)) continue;
        final pos = SpatialRepository.featureLonLat(f);
        if (pos == null ||
            ((pos[0] - p.longitude).abs() < tol &&
                (pos[1] - p.latitude).abs() < tol)) {
          match = f;
          break;
        }
      }
      if (match == null) {
        conflicts.add(p.id!);
        continue;
      }
      p.serverId = SpatialRepository.featureId(match);
      taken.add(p.serverId!);
      await _persist(p);
    }
    return conflicts;
  }

  /// Brings the server's points into this device's list:
  /// - points collected elsewhere (web / other devices) are added,
  /// - linked points get server metadata (layer, done by, uuid, ...),
  /// - downloaded points deleted on the server are removed here.
  Future<void> _mergeServerPoints(
      List<Map<String, dynamic>> features, String projectId) async {
    final byId = <int, Map<String, dynamic>>{};
    for (final f in features) {
      final sid = SpatialRepository.featureId(f);
      if (sid != null) byId[sid] = f;
    }

    final changed = <PointModel>[];
    final removed = <PointModel>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.serverId == null) continue;
      final f = byId.remove(p.serverId);
      if (f == null) {
        if (p.fromServer) removed.add(p);
        continue;
      }
      if (p.pendingSync) continue; // local edit not sent yet - keep it
      if (p.fromServer) {
        // Mirror the server copy (it may have been edited on the web).
        final fresh = PointModel.fromServerFeature(f, projectId);
        if (fresh != null &&
            jsonEncode(fresh.toJson()) != jsonEncode(p.toJson())) {
          points[i] = fresh;
          changed.add(fresh);
        }
      } else {
        final props =
            (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
        var ch = p.applyServerProperties(props);
        // The server is the reference for sent points: number and code
        // edited on the web (or another device) are taken over here.
        final no = SpatialRepository.featurePointNo(f);
        if (no != null && p.name != '$no') {
          p.name = '$no';
          ch = true;
        }
        final code = props['point_code']?.toString();
        if (code != null && code.isNotEmpty && code != p.code) {
          p.code = code;
          ch = true;
        }
        if (ch) changed.add(p);
      }
    }

    for (final f in byId.values) {
      final sp = PointModel.fromServerFeature(f, projectId);
      if (sp == null) continue;
      points.add(sp);
      changed.add(sp);
    }

    if (changed.isEmpty && removed.isEmpty) return;
    points.removeWhere(removed.contains);
    _sortPoints();

    final removeIds = removed.map((e) => e.id!).toSet();
    try {
      await _repo.saveAll(changed);
      await _repo.deleteAll(removeIds);
      if (_projectName != null) {
        await LocalStorageService()
            .savePoints(_projectName!, changed, removeIds: removeIds);
      }
    } catch (e) {
      if (kDebugMode) print('Saving server points failed: $e');
    }
  }

  void _sortPoints() {
    points.sort((a, b) {
      final na = int.tryParse(a.name), nb = int.tryParse(b.name);
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.name.compareTo(b.name);
    });
  }

  Future<void> _persist(PointModel p) async {
    await _repo.save(p);
    if (_projectName != null) {
      await LocalStorageService().savePoint(_projectName!, p);
    }
  }

  Future<void> _syncServerMaxPoint(String projectId) async {
    final id = int.tryParse(projectId);
    if (id == null) return;
    try {
      final max = await _spatialRepo.maxPoint(id);
      if (_projectId == projectId && max > _serverMaxPoint) {
        _serverMaxPoint = max;
        notifyListeners();
      }
    } catch (_) {
      // Offline – fall back to local numbering.
    }
  }

  Future<void> refresh() async {
    if (_projectId != null) {
      await load(_projectId!);
    }
  }

  Future<void> addPoint(PointModel p) async {
    // projectId must be set on the point
    await _persist(p);

    if (_projectId == p.projectId) {
      final idx = points.indexWhere((e) => e.id == p.id);
      if (idx >= 0) {
        points[idx] = p;
      } else {
        points.add(p);
      }
      notifyListeners();
    }
  }

  /// Saves an edited point locally and, if it was already sent,
  /// updates its code on the server too.
  ///
  /// If the server can't be reached the edit is kept, marked pending and
  /// retried on the next refresh. If the server rejects it, the point goes
  /// back to the server's values on the next refresh.
  Future<void> updatePoint(PointModel p) async {
    if (p.serverId != null) p.pendingSync = true;
    await addPoint(p);
    if (p.serverId == null) return;

    try {
      await _pushUpdate(p);
      await _persist(p);
      notifyListeners();
      refreshServerNumbers(); // old number is now free, new one taken
    } on PointSyncException catch (e) {
      if (!e.willRetry) {
        p.pendingSync = false;
        await _persist(p);
        notifyListeners();
        refreshServerNumbers(); // pulls the server's values back
      }
      rethrow;
    }
  }

  Map<String, dynamic> _serverProps(PointModel p) => {
        if (int.tryParse(p.name) != null) 'point_no': int.parse(p.name),
        'point_code':
            (p.code == null || p.code!.trim().isEmpty) ? 'PNT' : p.code!.trim(),
        if (p.instrumentHeight != null)
          'inst_height': p.instrumentHeight!.toStringAsFixed(3),
      };

  /// Sends a pending edit. Clears [PointModel.pendingSync] on success.
  Future<void> _pushUpdate(PointModel p) async {
    final Map<String, dynamic> res;
    try {
      res = await _spatialRepo.update(p.serverId!, properties: _serverProps(p));
    } on ApiException catch (e) {
      final retry = e.statusCode >= 500 || e.statusCode == 408;
      throw PointSyncException(
          retry
              ? 'Server error (${e.statusCode}) - change kept, will retry.'
              : 'Server rejected the change: ${e.body}',
          willRetry: retry);
    } catch (_) {
      throw PointSyncException(
          'No connection - change saved on this device and will be sent '
          'automatically.',
          willRetry: true);
    }
    // Make sure the server really took the new number.
    final want = int.tryParse(p.name);
    final got = SpatialRepository.featurePointNo(res);
    if (want != null && got != null && got != want) {
      throw PointSyncException(
          'Server kept point number $got - it did not accept the change '
          'to $want.',
          willRetry: false);
    }
    p.pendingSync = false;
  }

  /// Retries edits that couldn't be sent earlier. Stops at the first
  /// connection problem.
  Future<void> _retryPendingUpdates() async {
    for (final p in points.where((e) => e.pendingSync && e.serverId != null)) {
      try {
        await _pushUpdate(p);
      } on PointSyncException catch (e) {
        if (e.willRetry) return;
        p.pendingSync = false; // rejected - server values win
      }
      await _persist(p);
    }
  }

  /// Deletes on the server first (if sent), then locally. Throws if the
  /// server delete fails, so the point is never removed from the device only.
  Future<void> deletePoint(String id) async {
    final p = points.where((e) => e.id == id).firstOrNull;
    if (p?.serverId != null) {
      await _spatialRepo.delete(p!.serverId!);
    }
    await _repo.delete(id);
    if (_projectName != null) {
      await LocalStorageService().deletePoint(_projectName!, id);
    }
    points.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // HELPERS
  /// Next number after the highest one saved on the device or the server.
  String getNextPointNumber() {
    int max = _serverMaxPoint;
    for (final n in _serverNumbers) {
      if (n > max) max = n;
    }
    for (final p in points) {
      final val = int.tryParse(p.name) ?? 0;
      if (val > max) max = val;
    }
    return (max + 1).toString();
  }

  /// Checks [name] against points on this device and on the server.
  /// [excludeId] is the local id of a point being edited (its own number
  /// doesn't count as taken).
  PointNoStatus checkPointNumber(String name, {String? excludeId}) {
    final t = name.trim();
    final n = int.tryParse(t);
    if (t.isEmpty || n == null || n <= 0) return PointNoStatus.invalid;

    final self = excludeId == null
        ? null
        : points.where((p) => p.id == excludeId).firstOrNull;
    if (self != null && self.name.trim() == t) return PointNoStatus.available;

    if (points.any((p) => p.id != excludeId && int.tryParse(p.name) == n)) {
      return PointNoStatus.usedOnDevice;
    }
    if (_serverNumbers.contains(n)) return PointNoStatus.usedOnServer;
    return serverReachable ? PointNoStatus.available : PointNoStatus.unverified;
  }

  /// Same as [checkPointNumber] but refreshes from the server first.
  /// Use right before saving.
  Future<PointNoStatus> verifyPointNumber(String name,
      {String? excludeId}) async {
    await refreshServerNumbers();
    return checkPointNumber(name, excludeId: excludeId);
  }

  List<String> getRecentCodes() {
    final codes = <String>{};
    // Iterate in reverse to get most recent first
    for (var i = points.length - 1; i >= 0; i--) {
      final c = points[i].code;
      if (c != null && c.isNotEmpty) {
        codes.add(c);
        if (codes.length >= 3) break;
      }
    }
    return codes.toList();
  }

  // SEND TO BACKEND
  final _spatialRepo = SpatialRepository();

  SpatialRequestItem _toItem(PointModel p, int projectId, int layerId,
      int pointNo) {
    final sld = Sld99Converter.toSld99(p.latitude, p.longitude);
    return SpatialRequestItem(
      refCoordinate: SpatialGeometry(
        type: 'Point',
        coordinates: [sld['easting']!, sld['northing']!, p.altitude ?? 0.0],
        srid: 5235,
      ),
      geometry: SpatialGeometry(
        type: 'Point',
        coordinates: [
          p.longitude,
          p.latitude,
          p.altitude ?? 0.0
        ], // Backend requires 3D [lon, lat, alt]
      ),
      properties: SpatialProperties(
        projectId: projectId,
        layerId: layerId,
        pointNo: pointNo,
        pointCode: (p.code == null || p.code!.trim().isEmpty) ? 'PNT' : p.code!,
        instrumentHight: (p.instrumentHeight ?? BtViewModel.instance.correctedHI)
            .toStringAsFixed(3),
        hdop: p.hdop ?? 0.0,
        pdop: p.pdop ?? 0.0,
        vdop: p.vdop ?? 0.0,
        hrms: p.hrms,
        vrms: p.vrms,
        speed: p.speed,
        heading: p.heading,
        baseId: p.baseId,
        diffAge: p.diffAge,
        modeStatus: p.solutionType,
        parentUuid: [],
        area: null,
      ),
    );
  }

  /// Sends points not yet on the server.
  ///
  /// Before sending, the project's server points are checked: points that
  /// are already there (same number and position) are just marked as sent,
  /// and points whose number is used by a different point are reported as
  /// conflicts instead of being sent.
  Future<SendResult> sendData({int layerId = 1}) async {
    final result = SendResult();
    if (!points.any((p) => p.serverId == null)) return result;
    loading = true;
    notifyListeners();
    try {
      final projectIdInt = int.tryParse(_projectId ?? '0') ?? 0;
      final conflicts = <String>{};

      // 1. Pre-check against what the server already has.
      final syncedBefore = points.where((p) => p.serverId != null).length;
      try {
        conflicts.addAll(
            await _matchServer(await _spatialRepo.listByProject(projectIdInt)));
      } catch (_) {
        // Couldn't list - rely on the server's own duplicate check below.
      }
      result.alreadyOnServer =
          points.where((p) => p.serverId != null).length - syncedBefore;

      // 2. Build the batch. Points with non-numeric names get free numbers.
      final toSend = points
          .where((p) => p.serverId == null && !conflicts.contains(p.id))
          .toList();
      var nextFree = int.parse(getNextPointNumber());
      final numbers = [
        for (final p in toSend) int.tryParse(p.name) ?? nextFree++,
      ];

      // 3. Send; if the server rejected the whole batch because of some
      //    items, retry once without them.
      var batch = List<int>.generate(toSend.length, (i) => i);
      for (var attempt = 0; attempt < 2 && batch.isNotEmpty; attempt++) {
        final res = await _spatialRepo.sendBatch([
          for (final i in batch)
            _toItem(toSend[i], projectIdInt, layerId, numbers[i]),
        ]);
        final failed = <int>{};
        res.errors.forEach((idx, msgs) {
          if (idx < 0 || idx >= batch.length) return;
          final p = toSend[batch[idx]];
          failed.add(batch[idx]);
          if (SpatialSaveResult.isDuplicate(msgs)) {
            conflicts.add(p.id!);
          } else {
            result.failed.add('${p.name}: ${msgs.join('; ')}');
          }
        });
        final remaining = batch.where((i) => !failed.contains(i)).toList();
        if (res.errors.isEmpty || res.savedRecords.isNotEmpty) {
          result.sent += remaining.length; // saved
          if (res.savedRecords.isNotEmpty) await _matchServer(res.savedRecords);
          break;
        }
        batch = remaining; // nothing saved - retry the valid ones
      }

      result.conflicts.addAll(points
          .where((p) => conflicts.contains(p.id))
          .map((p) => p.name));

      // 4. Link server ids for what was saved.
      if (_projectId != null) {
        await refreshServerNumbers();
      }
      return result;
    } catch (e) {
      if (kDebugMode) print('Send error: $e');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // EXPORT CSV
  Future<String> exportCsv() async {
    loading = true;
    notifyListeners();
    try {
      const header = 'Name,Latitude,Longitude,Altitude,Timestamp,Solution\n';
      final rows = points.map((p) {
        return '${p.name},${p.latitude},${p.longitude},${p.altitude ?? ""},${p.timestamp.toIso8601String()},${p.solutionType ?? ""}';
      }).join('\n');

      final csvContent = header + rows;

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/points_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent);
      return file.path;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class SendResult {
  int sent = 0;

  /// Points found already on the server (same number and position) and
  /// just marked as sent.
  int alreadyOnServer = 0;

  /// Point names whose number is already used by a different point.
  final List<String> conflicts = [];

  /// Other per-point errors from the server.
  final List<String> failed = [];

  String get message {
    final parts = <String>[
      if (sent > 0) '$sent point(s) sent.',
      if (alreadyOnServer > 0) '$alreadyOnServer already on the server.',
      if (conflicts.isNotEmpty)
        'Point no. ${conflicts.join(', ')} already used on the server by a '
            'different point - change the number (edit) and send again.',
      if (failed.isNotEmpty) 'Failed: ${failed.join(' | ')}',
    ];
    return parts.isEmpty ? 'All points are already on the server.' : parts.join(' ');
  }

  bool get hasProblems => conflicts.isNotEmpty || failed.isNotEmpty;
}

enum PointNoStatus {
  available,

  /// Free on this device, but the server couldn't be reached to confirm.
  unverified,
  usedOnDevice,
  usedOnServer,
  invalid;

  bool get isTaken => this == usedOnDevice || this == usedOnServer;

  String get label => switch (this) {
        PointNoStatus.available => 'Available',
        PointNoStatus.unverified => 'Not checked on server (offline)',
        PointNoStatus.usedOnDevice => 'Already used on this device',
        PointNoStatus.usedOnServer => 'Already used on the server',
        PointNoStatus.invalid => 'Enter a number',
      };
}

class PointSyncException implements Exception {
  final String message;

  /// true = connection problem, the edit is kept and retried;
  /// false = the server refused it.
  final bool willRetry;
  PointSyncException(this.message, {required this.willRetry});
  @override
  String toString() => message;
}
