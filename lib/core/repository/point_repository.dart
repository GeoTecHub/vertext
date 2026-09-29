import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/point.dart';

class PointRepository {
  static const _kPoints = 'points_data';

  Future<List<PointModel>> list(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPoints);
    if (raw == null) return [];

    final allPoints = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => PointModel.fromJson(e))
        .toList();

    return allPoints.where((p) => p.projectId == projectId).toList();
  }

  Future<void> save(PointModel point) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPoints);

    List<PointModel> allPoints = [];
    if (raw != null) {
      allPoints = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => PointModel.fromJson(e))
          .toList();
    }

    if (point.id == null) {
      point.id = DateTime.now().millisecondsSinceEpoch.toString();
      allPoints.add(point);
    } else {
      final idx = allPoints.indexWhere((element) => element.id == point.id);
      if (idx >= 0) {
        allPoints[idx] = point;
      } else {
        allPoints.add(point);
      }
    }

    await prefs.setString(
        _kPoints, jsonEncode(allPoints.map((e) => e.toJson()).toList()));
  }

  /// Upserts many points with one write.
  Future<void> saveAll(List<PointModel> items) async {
    if (items.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPoints);
    final all = raw == null
        ? <PointModel>[]
        : (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map((e) => PointModel.fromJson(e))
            .toList();
    for (final p in items) {
      final idx = all.indexWhere((e) => e.id == p.id);
      if (idx >= 0) {
        all[idx] = p;
      } else {
        all.add(p);
      }
    }
    await prefs.setString(
        _kPoints, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// Removes many points with one write.
  Future<void> deleteAll(Set<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPoints);
    if (raw == null) return;
    final all = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .where((e) => !ids.contains(e['id']?.toString()))
        .toList();
    await prefs.setString(_kPoints, jsonEncode(all));
  }

  Future<void> delete(String pointId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPoints);
    if (raw == null) return;

    final allPoints = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => PointModel.fromJson(e))
        .toList();

    allPoints.removeWhere((p) => p.id == pointId);

    await prefs.setString(
        _kPoints, jsonEncode(allPoints.map((e) => e.toJson()).toList()));
  }
}
