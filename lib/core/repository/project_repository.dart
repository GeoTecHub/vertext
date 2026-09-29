import '../api/api_service.dart';
import '../models/lookup_item.dart';
import '../models/project.dart';

class ProjectRepository {
  final ApiService _api = ApiService();

  Future<List<ProjectModel>> list({bool? archive}) =>
      _api.getProjects(archive: archive);

  Future<ProjectModel> create(ProjectModel p) => _api.createProject(p);

  Future<ProjectModel> update(
    int id, {
    String? name,
    String? projection,
    String? surveyMethode,
    String? surveyAccuracy,
    String? clientName,
    List<String>? clientPhone,
    String? dateStart,
    String? dateEnd,
    String? note,
    List<int>? assignedMemberId,
    List<int>? gndId,
    String? village,
    String? certifiedDate,
    bool? archive,
    int? planNo,
    bool? isPlanIssued,
  }) =>
      _api.updateProject(
        id,
        name: name,
        projection: projection,
        surveyMethode: surveyMethode,
        surveyAccuracy: surveyAccuracy,
        clientName: clientName,
        clientPhone: clientPhone,
        dateStart: dateStart,
        dateEnd: dateEnd,
        note: note,
        assignedMemberId: assignedMemberId,
        gndId: gndId,
        village: village,
        certifiedDate: certifiedDate,
        archive: archive,
        planNo: planNo,
        isPlanIssued: isPlanIssued,
      );

  Future<void> delete(int id) => _api.deleteProject(id);

  Future<List<Map<String, dynamic>>> report(String from, String to) =>
      _api.getProjectReport(from: from, to: to);

  Future<dynamic> planNumberInfo() => _api.getPlanNumberInfo();

  // Lookups used by the job form
  Future<List<LookupItem>> dsdList() async =>
      (await _api.getDsdList()).map(LookupItem.dsd).toList();
  Future<List<LookupItem>> gndList({String? dsd}) async =>
      (await _api.getGndList(dsd: dsd)).map(LookupItem.gnd).toList();
  Future<List<LookupItem>> members() async =>
      (await _api.getOrgMembers()).map(LookupItem.member).toList();
}
