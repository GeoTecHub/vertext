import '../api/api_service.dart';
import '../models/login_request.dart';
import '../models/user_response.dart';
import '../storage/session_manager.dart';

class AuthRepository {
  final ApiService _api = ApiService();

  Future<UserResponse> login(String username, String password) =>
      _api.login(LoginRequest(username: username, password: password));

  /// Invalidates the token on the server (best effort, so logout still
  /// works offline) and clears the local session.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await SessionManager().clear();
  }

  /// True if the stored token is still accepted by the server.
  Future<bool> isTokenValid() async {
    try {
      await _api.userAuthentication();
      return true;
    } on ApiException catch (e) {
      return e.statusCode != 401 && e.statusCode != 403;
    }
  }

  Future<Map<String, dynamic>> me() => _api.me();

  Future<void> changePassword(String oldPw, String newPw, String confirmPw) =>
      _api.changePassword(
          oldPassword: oldPw, newPassword: newPw, confirmNewPassword: confirmPw);
}
