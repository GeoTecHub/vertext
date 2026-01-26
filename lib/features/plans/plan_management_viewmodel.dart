import 'package:flutter/foundation.dart';
import '../../core/models/project.dart';
import '../../core/repository/project_repository.dart';

class PlanManagementViewModel extends ChangeNotifier {
  final _repo = ProjectRepository();

  bool loading = false;
  String? error;
  List<ProjectModel> projects = [];
  ProjectModel? selectedProject;

  PlanManagementViewModel() {
    loadProjects();
  }

  Future<void> loadProjects() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      projects = await _repo.list();
      if (projects.isNotEmpty && selectedProject == null) {
        // Optionally select the first one, or leave null
        // selectedProject = projects.first;
      }
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  void selectProject(ProjectModel? project) {
    selectedProject = project;
    notifyListeners();
  }

  Future<void> uploadPlan(String planName) async {
    if (selectedProject == null) return;

    loading = true;
    notifyListeners();

    try {
      // TODO: Implement actual upload logic here
      await Future.delayed(const Duration(seconds: 2)); // Mock delay

      // Success
    } catch (e) {
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }
}
