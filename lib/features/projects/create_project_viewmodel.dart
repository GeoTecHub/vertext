import 'package:flutter/foundation.dart';
import '../../core/models/lookup_item.dart';
import '../../core/models/project.dart';
import '../../core/repository/project_repository.dart';
import '../../core/services/local_storage_service.dart';

class CreateProjectViewModel extends ChangeNotifier {
  final _repo = ProjectRepository();
  bool loading = false;
  String? error;

  // Lookups for the form pickers. If they fail to load, the view falls
  // back to typing ids manually.
  List<LookupItem> dsdList = [];
  List<LookupItem> gndList = [];
  List<LookupItem> members = [];
  bool lookupsLoading = false;
  bool gndLoading = false;
  String? lookupError;

  Future<void> loadLookups() async {
    lookupsLoading = true;
    lookupError = null;
    notifyListeners();
    try {
      final r = await Future.wait([_repo.dsdList(), _repo.members()]);
      dsdList = r[0];
      members = r[1].where((m) => m.id != null).toList();
    } catch (e) {
      lookupError = e.toString();
    }
    lookupsLoading = false;
    notifyListeners();
  }

  Future<void> loadGnd(String? dsd) async {
    gndList = [];
    if (dsd == null) {
      notifyListeners();
      return;
    }
    gndLoading = true;
    notifyListeners();
    try {
      gndList = (await _repo.gndList(dsd: dsd))
          .where((g) => g.id != null)
          .toList();
    } catch (e) {
      lookupError = e.toString();
    }
    gndLoading = false;
    notifyListeners();
  }

  Future<bool> createProject({
    required String name,
    required String projection,
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
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final now = DateTime.now().toIso8601String();
      final p = ProjectModel(
        projectName: name,
        dateCreated: now,
        projection: projection,
        surveyMethode: null,
        surveyAccuracy: null,
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
      await _repo.create(p);

      // Create local folder
      await LocalStorageService().createProjectFolder(name);

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
