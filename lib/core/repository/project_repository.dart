import '../api/api_service.dart';
import '../models/project.dart';

class ProjectRepository {
  final ApiService _api = ApiService();

  Future<List<ProjectModel>> list() => _api.getProjects();

  Future<ProjectModel> create(ProjectModel p) => _api.createProject(p);

  Future<ProjectModel> update(
    int id, {
    String? name,
    String? projection,
    String? surveyMethode,
    String? surveyAccuracy,
  }) =>
      _api.updateProject(
        id,
        name: name,
        projection: projection,
        surveyMethode: surveyMethode,
        surveyAccuracy: surveyAccuracy,
      );
}
