import 'package:flutter/foundation.dart';
import '../../core/models/project.dart';
import '../../core/repository/project_repository.dart';

class ProjectsViewModel extends ChangeNotifier {
  final _repo = ProjectRepository();
  bool loading = false;
  String? error;
  List<ProjectModel> items = [];

  Future<void> refresh() async {
    loading = true; error = null; notifyListeners();
    try {
      items = await _repo.list();
    } catch (e) {
      error = e.toString();
    }
    loading = false; notifyListeners();
  }

  Future<void> update(ProjectModel p, {String? name, String? projection}) async {
    loading = true; notifyListeners();
    try {
      final up = await _repo.update(
        p.projectId!,
        name: name ?? p.projectName,
        projection: projection ?? p.projection,
      );
      items = items.map((e) => e.projectId == p.projectId ? up : e).toList();
    } catch (e) {
      error = e.toString();
    }
    loading = false; notifyListeners();
  }
}
