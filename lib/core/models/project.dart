class ProjectModel {
  final int? projectId;
  final int? userId;
  final String projectName;
  final String dateCreated;
  final String? surveyMethode;
  final String? surveyAccuracy;
  final String projection;
  final String? clientName;
  final List<String>? clientPhone;
  final String? dateStart;
  final String? dateEnd;
  final String? note;
  final List<int>? assignedMemberId;
  final List<int>? gndId;
  final String? village;
  final String? certifiedDate;
  final bool? archive;
  final int? planNo;
  final bool? isPlanIssued;

  ProjectModel({
    this.projectId,
    this.userId,
    required this.projectName,
    required this.dateCreated,
    this.surveyMethode,
    this.surveyAccuracy,
    required this.projection,
    this.clientName,
    this.clientPhone,
    this.dateStart,
    this.dateEnd,
    this.note,
    this.assignedMemberId,
    this.gndId,
    this.village,
    this.certifiedDate,
    this.archive,
    this.planNo,
    this.isPlanIssued,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> j) => ProjectModel(
        projectId: j['project_id'],
        userId: j['user_id'],
        projectName: j['project_name'],
        dateCreated: j['date_created'],
        surveyMethode: j['survey_methode'],
        surveyAccuracy: j['survey_accuracy'],
        projection: j['projection'],
        clientName: j['client_name'],
        clientPhone: (j['client_phone'] as List?)?.cast<String>(),
        dateStart: j['date_start'],
        dateEnd: j['date_end'],
        note: j['note'],
        assignedMemberId: (j['assigned_member_id'] as List?)?.cast<int>(),
        gndId: (j['gnd_id'] as List?)?.cast<int>(),
        village: j['village'],
        certifiedDate: j['certified_date'],
        archive: j['archive'],
        planNo: j['plan_no'],
        isPlanIssued: j['is_plan_issued'],
      );

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'user_id': userId,
        'project_name': projectName,
        'date_created': dateCreated,
        'survey_methode': surveyMethode,
        'survey_accuracy': surveyAccuracy,
        'projection': projection,
        'client_name': clientName,
        'client_phone': clientPhone,
        'date_start': dateStart,
        'date_end': dateEnd,
        'note': note,
        'assigned_member_id': assignedMemberId,
        'gnd_id': gndId,
        'village': village,
        'certified_date': certifiedDate,
        'archive': archive,
        'plan_no': planNo,
        'is_plan_issued': isPlanIssued,
      };

  /// Body for POST user/projectdata/ – server-owned fields
  /// (project_id, user_id, date_created) are left out.
  Map<String, dynamic> toCreateJson() => {
        'project_name': projectName,
        'client_name': clientName,
        'client_phone': clientPhone ?? <String>[],
        'date_start': dateStart,
        'date_end': dateEnd,
        'projection': projection,
        'note': note,
        'assigned_member_id': assignedMemberId ?? <int>[],
        'gnd_id': gndId ?? <int>[],
        'village': village,
        'certified_date': certifiedDate,
        'archive': archive ?? false,
        'plan_no': planNo,
        'is_plan_issued': isPlanIssued ?? false,
        if (surveyMethode != null) 'survey_methode': surveyMethode,
        if (surveyAccuracy != null) 'survey_accuracy': surveyAccuracy,
      };
}
