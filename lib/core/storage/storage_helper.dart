import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../models/layer.dart';

class StorageHelper {
  // ---------------- existing keys ----------------
  static const _kProject = 'project_data';
  static const _kLayer = 'layer_data';

  // ---------------- NTRIP preset keys ------------
  static const _kNtripPresets = 'ntrip_presets_v1';

  // ---------- Existing: Project / Layer ----------
  static Future<void> saveProject(ProjectModel p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProject, jsonEncode(p.toJson()));
  }

  static Future<void> saveLayer(LayerModel l) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLayer, jsonEncode(l.toJson()));
  }

  static Future<ProjectModel?> getProject() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProject);
    return raw == null ? null : ProjectModel.fromJson(jsonDecode(raw));
  }

  static Future<LayerModel?> getLayer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLayer);
    return raw == null ? null : LayerModel.fromJson(jsonDecode(raw));
  }

  // --------------- NTRIP PRESETS -----------------
  // Keep the model local to avoid new files
  // (Name + caster creds; mountpoint is chosen fresh per connection)
  // You can move this to /core/models later if you prefer.
  static List<NtripPreset> _decodePresets(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => NtripPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String _encodePresets(List<NtripPreset> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static Future<List<NtripPreset>> getNtripPresets() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodePresets(prefs.getString(_kNtripPresets));
  }

  static Future<void> saveNtripPreset(NtripPreset p) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = _decodePresets(prefs.getString(_kNtripPresets));
    // upsert by name (case-insensitive)
    final i = cur.indexWhere((e) => e.name.toLowerCase() == p.name.toLowerCase());
    if (i >= 0) {
      cur[i] = p;
    } else {
      cur.add(p);
    }
    await prefs.setString(_kNtripPresets, _encodePresets(cur));
  }

  static Future<void> deleteNtripPresetByName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = _decodePresets(prefs.getString(_kNtripPresets));
    cur.removeWhere((e) => e.name.toLowerCase() == name.toLowerCase());
    await prefs.setString(_kNtripPresets, _encodePresets(cur));
  }

  static Future<NtripPreset?> findNtripPreset(String name) async {
    final cur = await getNtripPresets();
    try {
      return cur.firstWhere(
          (e) => e.name.trim().toLowerCase() == name.trim().toLowerCase());
    } catch (_) {
      return null;
    }
  }
}

// Simple inline model
class NtripPreset {
  final String name;
  final String host;
  final int port;
  final String user;
  final String password;

  NtripPreset({
    required this.name,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'user': user,
        'password': password,
      };

  factory NtripPreset.fromJson(Map<String, dynamic> j) => NtripPreset(
        name: j['name'] ?? '',
        host: j['host'] ?? '',
        port: (j['port'] is int) ? j['port'] : int.tryParse('${j['port']}') ?? 2101,
        user: j['user'] ?? '',
        password: j['password'] ?? '',
      );
}
