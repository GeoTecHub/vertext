import 'dart:typed_data';
import '../api/api_service.dart';

class DocumentRepository {
  final _api = ApiService();

  Future<dynamic> upload({
    required int projectId,
    required int category,
    required String filePath,
    String? remark,
  }) =>
      _api.uploadDoc(
          projectId: projectId,
          category: category,
          filePath: filePath,
          remark: remark);

  Future<List<Map<String, dynamic>>> list(int projectId) =>
      _api.getDocs(projectId);

  Future<dynamic> updateRemark(int docId, String remark) =>
      _api.updateDocRemark(docId, remark);

  Future<void> delete(int docId) => _api.deleteDoc(docId);

  Future<Uint8List> downloadZip(List<int> docIds) =>
      _api.downloadDocsZip(docIds);

  Future<dynamic> folderSize() => _api.getFolderSize();
}
