import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/point.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<String> _getProjectFolderPath(String projectName) async {
    Directory baseDir;
    if (Platform.isAndroid) {
      // Try to use public Documents folder
      baseDir = Directory('/storage/emulated/0');
      if (!await baseDir.exists()) {
        // Fallback usually not needed on standard Android, but just in case
        baseDir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    try {
      return await _ensureDir('${baseDir.path}/Vertext/Projects/$projectName');
    } on FileSystemException catch (e) {
      // No permission for public storage (e.g. Android 10 without
      // WRITE_EXTERNAL_STORAGE) – use the app-specific folder instead,
      // which never needs a permission.
      if (kDebugMode) print('Public storage unavailable, using app dir: $e');
      final appDir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      return _ensureDir('${appDir.path}/Vertext/Projects/$projectName');
    }
  }

  Future<String> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> createProjectFolder(String projectName) async {
    await _getProjectFolderPath(projectName);
  }

  Future<void> savePoint(String projectName, PointModel point) async {
    final folderPath = await _getProjectFolderPath(projectName);
    final file = File('$folderPath/points.json');

    List<PointModel> points = [];
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        points = jsonList.map((e) => PointModel.fromJson(e)).toList();
      } catch (e) {
        // If file is corrupt, start fresh or log error
        if (kDebugMode) print('Error reading points.json: $e');
      }
    }

    // Upsert
    final index = points.indexWhere((p) => p.id == point.id);
    if (index >= 0) {
      points[index] = point;
    } else {
      points.add(point);
    }

    await file
        .writeAsString(jsonEncode(points.map((e) => e.toJson()).toList()));
  }

  /// Upserts many points and removes [removeIds] with one write.
  Future<void> savePoints(String projectName, List<PointModel> items,
      {Set<String> removeIds = const {}}) async {
    if (items.isEmpty && removeIds.isEmpty) return;
    final points = await loadPoints(projectName);
    points.removeWhere((p) => removeIds.contains(p.id));
    for (final p in items) {
      final idx = points.indexWhere((e) => e.id == p.id);
      if (idx >= 0) {
        points[idx] = p;
      } else {
        points.add(p);
      }
    }
    final folderPath = await _getProjectFolderPath(projectName);
    await File('$folderPath/points.json')
        .writeAsString(jsonEncode(points.map((e) => e.toJson()).toList()));
  }

  Future<void> deletePoint(String projectName, String pointId) async {
    final points = await loadPoints(projectName);
    final before = points.length;
    points.removeWhere((p) => p.id == pointId);
    if (points.length == before) return;
    final folderPath = await _getProjectFolderPath(projectName);
    await File('$folderPath/points.json')
        .writeAsString(jsonEncode(points.map((e) => e.toJson()).toList()));
  }

  Future<List<PointModel>> loadPoints(String projectName) async {
    final folderPath = await _getProjectFolderPath(projectName);
    final file = File('$folderPath/points.json');

    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => PointModel.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) print('Error loading points from file: $e');
      return [];
    }
  }
}
