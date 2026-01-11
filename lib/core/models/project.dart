class ProjectModel {
  final int? projectId;
  final int? userId;
  final String projectName;
  final String dateCreated;
  final String? surveyMethode;
  final String? surveyAccuracy;
  final String projection;

  ProjectModel({
    this.projectId,
    this.userId,
    required this.projectName,
    required this.dateCreated,
    this.surveyMethode,
    this.surveyAccuracy,
    required this.projection,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> j) => ProjectModel(
    projectId: j['project_id'],
    userId: j['user_id'],
    projectName: j['project_name'],
    dateCreated: j['date_created'],
    surveyMethode: j['survey_methode'],
    surveyAccuracy: j['survey_accuracy'],
    projection: j['projection'],
  );

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'user_id': userId,
    'project_name': projectName,
    'date_created': dateCreated,
    'survey_methode': surveyMethode,
    'survey_accuracy': surveyAccuracy,
    'projection': projection,
  };
}
