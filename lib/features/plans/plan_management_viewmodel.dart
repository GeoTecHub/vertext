import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/project.dart';
import '../../core/repository/document_repository.dart';
import '../../core/repository/project_repository.dart';

class PlanManagementViewModel extends ChangeNotifier {
  final _repo = ProjectRepository();
  final _docs = DocumentRepository();

  /// `category` sent to user/upload_docs/. The Postman example uses 2;
  /// confirm the category meanings with the backend.
  static const int planCategory = 2;

  bool loading = false;
  bool uploading = false;
  String? error;
  List<ProjectModel> projects = [];
  ProjectModel? selectedProject;
  List<Map<String, dynamic>> documents = [];
  dynamic folderSize;

  PlanManagementViewModel() {
    loadProjects();
  }

  Future<void> loadProjects() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      projects = await _repo.list();
      // Keep the selection pointing at an instance from the new list.
      final selId = selectedProject?.projectId;
      selectedProject = projects.where((p) => p.projectId == selId).firstOrNull;
    } catch (e) {
      error = e.toString();
    }
    try {
      folderSize = await _docs.folderSize();
    } catch (_) {}

    loading = false;
    notifyListeners();
  }

  Future<void> selectProject(ProjectModel? project) async {
    selectedProject = project;
    documents = [];
    notifyListeners();
    await loadDocuments();
  }

  Future<void> loadDocuments() async {
    final id = selectedProject?.projectId;
    if (id == null) return;
    error = null;
    try {
      documents = await _docs.list(id);
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<bool> uploadPlan(String filePath, {String? remark}) async {
    final id = selectedProject?.projectId;
    if (id == null) return false;

    uploading = true;
    error = null;
    notifyListeners();

    try {
      await _docs.upload(
        projectId: id,
        category: planCategory,
        filePath: filePath,
        remark: (remark == null || remark.trim().isEmpty) ? null : remark.trim(),
      );
      await loadDocuments();
      try {
        folderSize = await _docs.folderSize();
      } catch (_) {}
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      uploading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(int docId) async {
    try {
      await _docs.delete(docId);
      documents = documents.where((d) => docIdOf(d) != docId).toList();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateRemark(int docId, String remark) async {
    try {
      await _docs.updateRemark(docId, remark);
      await loadDocuments();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// Downloads the given documents as a ZIP into temp storage and returns
  /// its path (null on failure).
  Future<String?> downloadZip(List<int> docIds) async {
    if (docIds.isEmpty) return null;
    try {
      final bytes = await _docs.downloadZip(docIds);
      final dir = await getTemporaryDirectory();
      final name = selectedProject?.projectName.replaceAll(
              RegExp(r'[^A-Za-z0-9_-]'), '_') ??
          'documents';
      final file = File('${dir.path}/${name}_docs.zip');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ── helpers for the untyped document rows ────────────────────────────

  static int? docIdOf(Map<String, dynamic> d) {
    for (final k in const ['id', 'doc_id']) {
      final v = d[k];
      if (v is num) return v.toInt();
      if (v is String && int.tryParse(v) != null) return int.parse(v);
    }
    return null;
  }

  static String docNameOf(Map<String, dynamic> d) {
    for (final k in const ['file_name', 'name', 'file_path', 'file']) {
      final v = d[k];
      if (v is String && v.isNotEmpty) return v.split('/').last;
    }
    return 'Document ${docIdOf(d) ?? ''}';
  }

  static String? remarkOf(Map<String, dynamic> d) => d['remark'] as String?;
}
