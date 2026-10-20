import 'package:flutter/foundation.dart';
import '../../core/models/project.dart';
import '../../core/repository/project_repository.dart';
import '../../core/storage/session_manager.dart';

class ProjectsViewModel extends ChangeNotifier {
  final _repo = ProjectRepository();
  bool loading = false;
  String? error;
  List<ProjectModel> items = [];
  String? selectedProjectId;
  String? _storedProjectName;

  ProjectsViewModel() {
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    selectedProjectId = await SessionManager().getSelectedProjectId();
    _storedProjectName = await SessionManager().getSelectedProjectName();
    notifyListeners();
  }

  Future<void> select(String? id) async {
    selectedProjectId = id;
    await SessionManager().saveSelectedProjectId(id);

    // Find name
    String? name;
    if (id != null) {
      try {
        final p = items.firstWhere((e) => e.projectId.toString() == id);
        name = p.projectName;
      } catch (_) {}
    }
    _storedProjectName = name;
    await SessionManager().saveSelectedProjectName(name);

    notifyListeners();
  }

  String get selectedProjectName {
    if (selectedProjectId == null) return "No Project";

    // Try from items first
    try {
      final p =
          items.firstWhere((e) => e.projectId.toString() == selectedProjectId);
      return p.projectName;
    } catch (_) {
      // Fallback to stored
      return _storedProjectName ?? "Unknown Project";
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _repo.list();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> update(ProjectModel p,
      {String? name, String? projection}) async {
    loading = true;
    notifyListeners();
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
    loading = false;
    notifyListeners();
  }

  Future<bool> delete(ProjectModel p) async {
    if (p.projectId == null) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _repo.delete(p.projectId!);
      items = items.where((e) => e.projectId != p.projectId).toList();
      if (selectedProjectId == p.projectId.toString()) await select(null);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
