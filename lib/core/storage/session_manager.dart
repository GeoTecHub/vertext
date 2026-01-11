import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_response.dart';
import '../models/layer.dart';

class SessionManager {
  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kLayers = 'layers';

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kToken) && prefs.containsKey(_kUser);
    }

  Future<void> saveUserResponse(UserResponse res) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, res.token);
    await prefs.setString(_kUser, jsonEncode({
      'token': res.token, // optional duplication
      'user': {
        'id': res.user.id,
        'username': res.user.username,
        'email': res.user.email,
        'user_type': res.user.userType,
        'is_active': res.user.isActive,
        'first_name': res.user.firstName,
        'last_name': res.user.lastName,
        'display_name': res.user.displayName,
        'license_number': res.user.licenseNumber,
        'mobile': res.user.mobile,
        'address': res.user.address,
      }
    }));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<void> saveLayers(List<LayerModel> layers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLayers,
        jsonEncode(layers.map((e) => e.toJson()).toList()));
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
  }
}
