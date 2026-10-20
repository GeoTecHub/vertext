import 'package:flutter/foundation.dart';
import '../../core/repository/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  final _repo = AuthRepository();
  bool loading = false;
  String? error;

  Future<bool> login(String username, String password) async {
    loading = true; error = null; notifyListeners();
    try {
      await _repo.login(username, password);
      loading = false; notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      loading = false; notifyListeners();
      return false;
    }
  }
}
