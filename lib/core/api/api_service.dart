import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/login_request.dart';
import '../models/user_response.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/spatial_data_model.dart';
import '../storage/session_manager.dart';
import 'api_client.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String body;
  ApiException(this.message, this.statusCode, [this.body = '']);
  @override
  String toString() =>
      '$message ($statusCode)${body.isNotEmpty ? ': $body' : ''}';
}

class ApiService {
  final ApiClient _client;
  final SessionManager _session;
  ApiService({ApiClient? client, SessionManager? session})
      : _client = client ?? ApiClient(),
        _session = session ?? SessionManager();

  // ── helpers ──────────────────────────────────────────────────────────

  Future<Map<String, String>> _auth({bool json = false}) async {
    final token = await _session.getToken();
    if (token == null) throw Exception('No token');
    return {
      'Authorization': 'Token $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static bool _ok(http.Response r) =>
      r.statusCode >= 200 && r.statusCode < 300;

  static dynamic _decode(http.Response r) =>
      r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));

  static dynamic _expect(http.Response r, String what) {
    if (_ok(r)) return _decode(r);
    throw ApiException('$what failed', r.statusCode, r.body);
  }

  static List<Map<String, dynamic>> _asList(dynamic d) {
    if (d is List) return d.cast<Map<String, dynamic>>();
    // Some list endpoints may wrap results, e.g. {"data": [...]}.
    if (d is Map) {
      for (final k in const ['data', 'results', 'features']) {
        if (d[k] is List) return (d[k] as List).cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  static List<dynamic> _asRawList(dynamic d) {
    if (d is List) return d;
    if (d is Map) {
      for (final k in const ['data', 'results']) {
        if (d[k] is List) return d[k] as List;
      }
    }
    return [];
  }

  Future<dynamic> _get(String path, String what,
      {Map<String, String>? query}) async {
    final r = await _client.get(_client.uri(path, query),
        headers: await _auth());
    return _expect(r, what);
  }

  Future<dynamic> _post(String path, Object? body, String what) async {
    final r = await _client.post(_client.uri(path),
        headers: await _auth(json: true),
        body: body == null ? null : jsonEncode(body));
    return _expect(r, what);
  }

  Future<dynamic> _patch(String path, Object body, String what) async {
    final r = await _client.patch(_client.uri(path),
        headers: await _auth(json: true), body: jsonEncode(body));
    return _expect(r, what);
  }

  Future<dynamic> _delete(String path, String what, {Object? body}) async {
    final r = await _client.delete(_client.uri(path),
        headers: await _auth(json: body != null),
        body: body == null ? null : jsonEncode(body));
    return _expect(r, what);
  }

  // ── AUTH / USER ──────────────────────────────────────────────────────

  Future<UserResponse> login(LoginRequest req) async {
    final res = await _client.post(
      _client.uri('user/login/'),
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

  /// Invalidates the token on the server. Local session is cleared by caller.
  Future<void> logout() => _post('user/logout/', null, 'Logout');

  /// Checks that the stored token is still valid.
  Future<Map<String, dynamic>?> userAuthentication() async =>
      await _post('user/user-authentication/', null, 'User authentication')
          as Map<String, dynamic>?;

  Future<Map<String, dynamic>> me() async =>
      await _get('user/me/', 'Load profile') as Map<String, dynamic>;

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) =>
      _post(
          'user/change_password/',
          {
            'old_password': oldPassword,
            'new_password': newPassword,
            'confirm_new_password': confirmNewPassword,
          },
          'Change password');

  /// Admin: create a user in own organisation.
  /// Fields: username, first_name, last_name, email, mobile, address,
  /// nic, license_number.
  Future<dynamic> createUser(Map<String, dynamic> user) =>
      _post('user/create/', user, 'Create user');

  /// Public sign-up of an organisation admin (no token required).
  Future<dynamic> createPublicAdmin(Map<String, dynamic> user) async {
    final r = await _client.post(_client.uri('user/create_public_admin/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(user));
    return _expect(r, 'Create admin');
  }

  /// Sign-up of an invited member (no token required).
  /// Fields: username, first_name, last_name, nic, email, mobile, address,
  /// org_id, user_type, password.
  Future<dynamic> createInvitedUser(Map<String, dynamic> user) async {
    final r = await _client.post(_client.uri('user/create_invited_user/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(user));
    return _expect(r, 'Create invited user');
  }

  Future<dynamic> updateUser(int userId, Map<String, dynamic> fields) =>
      _patch('user/update/user_id=$userId/', fields, 'Update user');

  Future<void> deleteUser(int userId) =>
      _delete('user/delete/$userId/', 'Delete user');

  Future<List<Map<String, dynamic>>> getOrgMembers() async =>
      _asList(await _get('user/org_members/', 'Load members'));

  // ── LAYERS ───────────────────────────────────────────────────────────

  Future<List<LayerModel>> getLayers() async {
    final list = _asList(await _get('user/layerdata/', 'Load layers'))
        .map(LayerModel.fromJson)
        .toList();
    await _session.saveLayers(list);
    return list;
  }

  Future<LayerModel> createLayer({
    required String name,
    required String colour,
  }) async {
    final layer = LayerModel.fromJson(await _post(
        'user/layerdata/', {'layer_name': name, 'colour': colour},
        'Create layer'));
    // best-effort cache update
    try {
      final cached = await _session.getLayers();
      await _session.saveLayers([...cached, layer]);
    } catch (_) {}
    return layer;
  }

  Future<LayerModel> updateLayer({
    required int id,
    String? name,
    String? colour,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'layer_name': name,
      if (colour != null) 'colour': colour,
    };
    final updated = LayerModel.fromJson(await _patch(
        'user/layerdata/modify/id=$id/', payload, 'Update layer'));
    try {
      final cached = await _session.getLayers();
      await _session.saveLayers(cached
          .map((l) => l.layerId == updated.layerId ? updated : l)
          .toList());
    } catch (_) {}
    return updated;
  }

  Future<bool> deleteLayer(int id) async {
    final res = await _client.delete(
      _client.uri('user/layerdata/modify/id=$id/'),
      headers: await _auth(),
    );
    final success = _ok(res);
    if (success) {
      try {
        final cached = await _session.getLayers();
        await _session
            .saveLayers(cached.where((l) => l.layerId != id).toList());
      } catch (_) {}
    }
    return success;
  }

  // ── PROJECTS (JOBS) ──────────────────────────────────────────────────

  /// [archive] filters by archive status; null returns the default list.
  Future<List<ProjectModel>> getProjects({bool? archive}) async =>
      _asList(await _get('user/projectdata/', 'Load projects',
              query: archive == null ? null : {'archive': '$archive'}))
          .map(ProjectModel.fromJson)
          .toList();

  Future<ProjectModel> createProject(ProjectModel p) async =>
      ProjectModel.fromJson(
          await _post('user/projectdata/', p.toCreateJson(), 'Create project'));

  Future<ProjectModel> updateProject(
    int id, {
    String? name,
    String? projection,
    String? surveyMethode,
    String? surveyAccuracy,
    String? clientName,
    List<String>? clientPhone,
    String? dateStart,
    String? dateEnd,
    String? note,
    List<int>? assignedMemberId,
    List<int>? gndId,
    String? village,
    String? certifiedDate,
    bool? archive,
    int? planNo,
    bool? isPlanIssued,
  }) async {
    final payload = {
      if (name != null) 'project_name': name,
      if (projection != null) 'projection': projection,
      if (surveyMethode != null) 'survey_methode': surveyMethode,
      if (surveyAccuracy != null) 'survey_accuracy': surveyAccuracy,
      if (clientName != null) 'client_name': clientName,
      if (clientPhone != null) 'client_phone': clientPhone,
      if (dateStart != null) 'date_start': dateStart,
      if (dateEnd != null) 'date_end': dateEnd,
      if (note != null) 'note': note,
      if (assignedMemberId != null) 'assigned_member_id': assignedMemberId,
      if (gndId != null) 'gnd_id': gndId,
      if (village != null) 'village': village,
      if (certifiedDate != null) 'certified_date': certifiedDate,
      if (archive != null) 'archive': archive,
      if (planNo != null) 'plan_no': planNo,
      if (isPlanIssued != null) 'is_plan_issued': isPlanIssued,
    };
    return ProjectModel.fromJson(await _patch(
        'user/projectdata/modify/id=$id/', payload, 'Update project'));
  }

  Future<void> deleteProject(int id) =>
      _delete('user/projectdata/modify/id=$id/', 'Delete project');

  /// Jobs in a date range (dates as yyyy-MM-dd).
  Future<List<Map<String, dynamic>>> getProjectReport(
          {required String from, required String to}) async =>
      _asList(await _post('user/projectdata/rpt_list/',
          {'from': from, 'to': to}, 'Load job report'));

  Future<dynamic> getPlanNumberInfo() =>
      _get('user/plan_no/', 'Load plan number info');

  // ── SPATIAL DATA ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSpatialByProject(int projectId) async =>
      _asList(await _get(
          'user/spatialdata/project_id=$projectId/', 'Load spatial'));

  Future<List<Map<String, dynamic>>> getAllSpatial() async =>
      _asList(await _get('user/spatialdata/all/', 'Load spatial'));

  /// Saves a single feature. The API takes an array, so this wraps
  /// [geometry] + [properties] into one item.
  Future<Map<String, dynamic>> createSpatial({
    required int projectId,
    required int layerId,
    required Map<String, dynamic> geometry,
    Map<String, dynamic> properties = const {},
    Map<String, dynamic>? refCoordinate,
  }) async {
    final geom = Map<String, dynamic>.from(geometry);
    geom['srid'] ??= 4326;
    if (geom['type'] == 'Point') {
      final c = (geom['coordinates'] as List).cast<num>();
      if (c.length == 2) geom['coordinates'] = [c[0], c[1], 0.0];
    }
    final res = await _post(
      'user/spatialdata/',
      [
        {
          'geometry': geom,
          'ref_coordinate': refCoordinate,
          'properties': {
            'area': null,
            'parent_uuid': [],
            ...properties,
            'project_id': projectId,
            'layer_id': layerId,
          },
        }
      ],
      'Create spatial',
    );
    if (res is List && res.isNotEmpty) return res.first as Map<String, dynamic>;
    if (res is Map<String, dynamic>) return res;
    return {'geometry': geom, 'properties': properties};
  }

  /// PATCH user/spatialdata/modify/id=X/ with
  /// {"properties": {layer_id, area, point_code, inst_height}}.
  Future<Map<String, dynamic>> updateSpatial(
    int id, {
    Map<String, dynamic>? geometry,
    Map<String, dynamic>? properties,
  }) async {
    final payload = <String, dynamic>{
      if (geometry != null) 'geometry': geometry,
      if (properties != null) 'properties': properties,
    };
    final res = await _patch(
        'user/spatialdata/modify/id=$id/', payload, 'Update spatial');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteSpatial(int id) =>
      _delete('user/spatialdata/modify/id=$id/', 'Delete spatial');

  Future<void> deleteSpatialBulk(List<int> ids) => _delete(
      'user/spatialdata/delete/', 'Delete spatial',
      body: {'spatial_id': ids});

  /// Batch save of collected points/lines/polygons. Item-level validation
  /// errors (HTTP 400 with an "errors" list) are returned, not thrown, so
  /// the caller can tell which items failed.
  Future<SpatialSaveResult> sendSpatialData(
      List<SpatialRequestItem> items) async {
    final r = await _client.post(_client.uri('user/spatialdata/'),
        headers: await _auth(json: true),
        body: jsonEncode(items.map((e) => e.toJson()).toList()));
    if (_ok(r)) return SpatialSaveResult.fromJson(_decode(r));
    if (r.statusCode == 400) {
      try {
        final body = _decode(r);
        if (body is Map && body['errors'] is List) {
          return SpatialSaveResult.fromJson(body);
        }
      } catch (_) {}
    }
    throw ApiException('Send spatial data failed', r.statusCode, r.body);
  }

  /// Highest point number stored on the server for a project (0 if none).
  Future<int> getMaxPoint(int projectId) async =>
      _findInt(await _get(
          'user/maxpoint/project_id=$projectId/', 'Load max point')) ??
      0;

  static int? _findInt(dynamic d) {
    if (d is num) return d.toInt();
    if (d is String) return int.tryParse(d);
    if (d is List && d.isNotEmpty) return _findInt(d.first);
    if (d is Map) {
      for (final k in const ['max_point', 'max_point_no', 'point_no', 'max']) {
        final v = _findInt(d[k]);
        if (v != null) return v;
      }
      // Fallback: any key mentioning max/point, but never ids
      // (e.g. project_id would otherwise be mistaken for the max point).
      for (final e in d.entries) {
        final k = '${e.key}'.toLowerCase();
        if (k.contains('id')) continue;
        if (!k.contains('max') && !k.contains('point')) continue;
        final n = _findInt(e.value);
        if (n != null) return n;
      }
    }
    return null;
  }

  // ── DOCUMENTS ────────────────────────────────────────────────────────

  Future<dynamic> uploadDoc({
    required int projectId,
    required int category,
    required String filePath,
    String? remark,
  }) async {
    final req =
        http.MultipartRequest('POST', _client.uri('user/upload_docs/'))
          ..headers.addAll(await _auth())
          ..fields['prj_id'] = '$projectId'
          ..fields['category'] = '$category'
          ..files.add(await http.MultipartFile.fromPath('file_path', filePath));
    if (remark != null) req.fields['remark'] = remark;
    return _expect(await _client.send(req), 'Upload document');
  }

  Future<List<Map<String, dynamic>>> getDocs(int projectId) async =>
      _asList(await _get('user/retrieve_docs/', 'Load documents',
          query: {'prj_id': '$projectId'}));

  Future<dynamic> updateDocRemark(int docId, String remark) =>
      _patch('user/update_docs/id=$docId/', {'remark': remark},
          'Update document');

  Future<void> deleteDoc(int docId) =>
      _delete('user/delete_docs/$docId/', 'Delete document');

  /// Returns the ZIP file bytes.
  Future<Uint8List> downloadDocsZip(List<int> docIds) async {
    final r = await _client.post(
        _client.uri('user/projectdata/download_zip/'),
        headers: await _auth(json: true),
        body: jsonEncode({'doc_ids': docIds}));
    if (_ok(r)) return r.bodyBytes;
    throw ApiException('Download ZIP failed', r.statusCode, r.body);
  }

  Future<dynamic> getFolderSize() =>
      _get('user/folder_size/', 'Load storage usage');

  // ── ADMIN AREAS ──────────────────────────────────────────────────────

  /// Rows may be objects or plain names – see LookupItem.
  Future<List<dynamic>> getDsdList() async =>
      _asRawList(await _get('user/dsd_data/', 'Load DSD list'));

  Future<List<dynamic>> getGndList({String? dsd}) async =>
      _asRawList(await _get('user/gnd_data/', 'Load GND list',
          query: dsd == null ? null : {'dsd': dsd}));

  // ── ORGANISATION / SUBSCRIPTION ──────────────────────────────────────

  Future<dynamic> getOrgDetails() =>
      _get('org/org_details/', 'Load organisation');

  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async =>
      _asList(await _get('org/subs_plan/', 'Load subscription plans'));

  /// Fields: subs_name, font_colour, back_colour, icon, allowed_storage,
  /// users_limit, remark.
  Future<dynamic> createSubscriptionPlan(Map<String, dynamic> plan) =>
      _post('org/subs_plan/', plan, 'Create subscription plan');

  Future<dynamic> updateSubscriptionPlan(int id, Map<String, dynamic> fields) =>
      _patch('org/update_subs_plan/$id/', fields, 'Update subscription plan');
}
