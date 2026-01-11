import 'package:flutter/foundation.dart';
import '../../core/models/project.dart';
import '../../core/repository/project_repository.dart';

class CreateProjectViewModel extends ChangeNotifier {
  final _repo = ProjectRepository();
  bool loading = false;
  String? error;

  Future<bool> createProject({
    required String name,
    required String projection,
  }) async {
    loading = true; error = null; notifyListeners();
    try {
      final now = DateTime.now().toIso8601String();
      final p = ProjectModel(
        projectName: name,
        dateCreated: now,
        projection: projection,
        surveyMethode: null,
        surveyAccuracy: null,
      );
      await _repo.create(p);
      loading = false; notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      loading = false; notifyListeners();
      return false;
    }
  }
}
