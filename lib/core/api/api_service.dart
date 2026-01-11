import 'dart:convert';
import '../models/login_request.dart';
import '../models/user_response.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../storage/session_manager.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient _client;
  final SessionManager _session;
  ApiService({ApiClient? client, SessionManager? session})
      : _client = client ?? ApiClient(),
        _session = session ?? SessionManager();

  // LOGIN
  Future<UserResponse> login(LoginRequest req) async {
    final res = await _client.post(
      _client.uri('api/user/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(req.toJson()),
    );
    if (res.statusCode == 200) {
      final data = UserResponse.fromJson(jsonDecode(res.body));
      await _session.saveUserResponse(data);
      return data;
    }
    throw Exception('Invalid credentials (${res.statusCode})');
  }

  // LAYERS CRUD
  Future<List<LayerModel>> getLayers() async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.get(
      _client.uri('api/user/layerdata_get/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List)
          .map((e) => LayerModel.fromJson(e))
          .toList();
      await _session.saveLayers(list);
      return list;
    }
    throw Exception('Failed to load layers (${res.statusCode})');
  }

  Future<LayerModel> createLayer({
    required String name,
    required String colour,
  }) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.post(
      _client.uri('api/user/layerdata/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'layer_name': name, 'colour': colour}),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      final layer = LayerModel.fromJson(jsonDecode(res.body));
      // best-effort cache update
      try {
        final cached = await _session.getLayers();
        final updated = List<LayerModel>.from(cached)..add(layer);
        await _session.saveLayers(updated);
      } catch (_) {}
      return layer;
    }
    throw Exception('Create layer failed (${res.statusCode})');
  }

  Future<LayerModel> updateLayer({
    required int id,
    String? name,
    String? colour,
  }) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final payload = <String, dynamic>{};
    if (name != null) payload['layer_name'] = name;
    if (colour != null) payload['colour'] = colour;

    final res = await _client.patch(
      _client.uri('api/user/layerdata/modify/id=$id'),
      headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      final updated = LayerModel.fromJson(jsonDecode(res.body));
      // best-effort cache update — use layerId
      try {
        final cached = await _session.getLayers();
        final updatedList = cached
            .map((l) => l.layerId == updated.layerId ? updated : l)
            .toList();
        await _session.saveLayers(updatedList);
      } catch (_) {}
      return updated;
    }
    throw Exception('Update layer failed (${res.statusCode})');
  }

  Future<bool> deleteLayer(int id) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.delete(
      _client.uri('api/user/layerdata/modify/id=$id'),
      headers: {'Authorization': 'Token $token'},
    );
    final success = res.statusCode == 204 || res.statusCode == 200;

    if (success) {
      // best-effort cache update — use layerId
      try {
        final cached = await _session.getLayers();
        final updated = cached.where((l) => l.layerId != id).toList();
        await _session.saveLayers(updated);
      } catch (_) {}
    }
    return success;
  }

  // PROJECTS LIST + EDIT
  Future<List<ProjectModel>> getProjects() async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.get(
      _client.uri('api/user/projectdata/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => ProjectModel.fromJson(e))
          .toList();
    }
    throw Exception('Load projects failed (${res.statusCode})');
  }

  Future<ProjectModel> createProject(ProjectModel p) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.post(
      _client.uri('api/user/projectdata/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(p.toJson()),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return ProjectModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create project (${res.statusCode})');
  }

  Future<ProjectModel> updateProject(
    int id, {
    String? name,
    String? projection,
    String? surveyMethode,
    String? surveyAccuracy,
  }) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final payload = {
      if (name != null) 'project_name': name,
      if (projection != null) 'projection': projection,
      if (surveyMethode != null) 'survey_methode': surveyMethode,
      if (surveyAccuracy != null) 'survey_accuracy': surveyAccuracy,
    };
    final res = await _client.patch(
      _client.uri('api/user/projectdata/modify/id=$id'),
      headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) return ProjectModel.fromJson(jsonDecode(res.body));
    throw Exception('Update project failed (${res.statusCode})');
  }

  // SPATIAL DATA
  Future<List<Map<String, dynamic>>> getSpatialByProject(int projectId) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.get(
      _client.uri('api/user/spatialdata/project_id=$projectId/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return (decoded as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Load spatial failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> createSpatial({
    required int projectId,
    required int layerId,
    required Map<String, dynamic> geometry,
    required Map<String, dynamic> attributes,
  }) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final res = await _client.post(
      _client.uri('api/user/spatialdata/'),
      headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'project_id': projectId,
        'layer_id': layerId,
        'geometry': geometry,
        'attributes': attributes,
      }),
    );
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Create spatial failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> updateSpatial(
    int id, {
    Map<String, dynamic>? geometry,
    Map<String, dynamic>? attributes,
  }) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    final payload = <String, dynamic>{};
    if (geometry != null) payload['geometry'] = geometry;
    if (attributes != null) payload['attributes'] = attributes;

    final res = await _client.patch(
      _client.uri('api/user/spatialdata/update/id=$id'),
      headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Update spatial failed (${res.statusCode})');
  }
}
