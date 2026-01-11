import '../api/api_service.dart';
import '../models/login_request.dart';
import '../models/user_response.dart';

class AuthRepository {
  final ApiService _api = ApiService();
  Future<UserResponse> login(String username, String password) =>
      _api.login(LoginRequest(username: username, password: password));
}
