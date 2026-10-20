import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_response.dart';
import '../models/layer.dart';

class SessionManager {
  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kLayers = 'layers';
  static const _kSelectedProjectId = 'selected_project_id';
  static const _kSelectedProjectName = 'selected_project_name';

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kToken) && prefs.containsKey(_kUser);
  }

  Future<void> saveUserResponse(UserResponse res) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, res.token);
    await prefs.setString(
        _kUser,
        jsonEncode({
          'token': res.token, // optional duplication
          'user': {
            'user_is_active': res.user.userIsActive,
            'organization_is_active': res.user.organizationIsActive,
            'subscription_is_expired': res.user.subscriptionIsExpired,
          }
        }));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<void> saveLayers(List<LayerModel> layers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLayers, jsonEncode(layers.map((e) => e.toJson()).toList()));
  }

  Future<List<LayerModel>> getLayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLayers);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) => LayerModel.fromJson(e)).toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    await prefs.remove(_kLayers);
    await prefs.remove(_kSelectedProjectId);
    await prefs.remove(_kSelectedProjectName);
  }

  Future<void> saveSelectedProjectId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kSelectedProjectId);
    } else {
      await prefs.setString(_kSelectedProjectId, id);
    }
  }

  Future<String?> getSelectedProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedProjectId);
  }

  Future<void> saveSelectedProjectName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_kSelectedProjectName);
    } else {
      await prefs.setString(_kSelectedProjectName, name);
    }
  }

  Future<String?> getSelectedProjectName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedProjectName);
  }
}
