import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'plan_management_viewmodel.dart';
import '../../core/models/project.dart';

class PlanManagementView extends StatefulWidget {
  const PlanManagementView({super.key});

  @override
  State<PlanManagementView> createState() => _PlanManagementViewState();
}

class _PlanManagementViewState extends State<PlanManagementView> {
  PlatformFile? _picked;
  final _remark = TextEditingController();

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles();
    if (res != null && res.files.single.path != null) {
      setState(() => _picked = res.files.single);
    }
  }

  Future<void> _upload(PlanManagementViewModel vm) async {
    final path = _picked?.path;
    if (path == null) return;
    final ok = await vm.uploadPlan(path, remark: _remark.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Uploaded ${_picked!.name}' : 'Upload failed')));
    if (ok) {
      setState(() => _picked = null);
      _remark.clear();
    }
  }

  Future<void> _editRemark(
      PlanManagementViewModel vm, int id, String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit remark'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) await vm.updateRemark(id, value);
  }

  Future<void> _delete(PlanManagementViewModel vm, int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text('The file will be removed from the server.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await vm.deleteDocument(id);
  }

  Future<void> _shareZip(PlanManagementViewModel vm) async {
    final ids = vm.documents
        .map(PlanManagementViewModel.docIdOf)
        .whereType<int>()
        .toList();
    final path = await vm.downloadZip(ids);
    if (path != null) {
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'Project documents');
    }
  }

  static String _formatSize(dynamic s) {
    num? bytes;
    if (s is num) bytes = s;
    if (s is Map) {
      final v = s.values.firstWhere((v) => v is num, orElse: () => null);
      if (v is num) bytes = v;
    }
    if (bytes == null) return '$s';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlanManagementViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Management'),
        actions: [
          if (vm.documents.isNotEmpty)
            IconButton(
              tooltip: 'Download all as ZIP',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => _shareZip(vm),
            ),
        ],
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await vm.loadProjects();
                await vm.loadDocuments();
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (vm.error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          vm.error!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                  const Text(
                    'Select Project',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProjectModel>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    initialValue: vm.selectedProject,
                    hint: const Text('Choose a project...'),
                    isExpanded: true,
                    items: vm.projects.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.projectName),
                      );
                    }).toList(),
                    onChanged: (val) => vm.selectProject(val),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Upload Plan / Document',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: vm.uploading ? null : _pickFile,
                          child: Column(
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 48, color: Colors.grey.shade600),
                              const SizedBox(height: 12),
                              Text(
                                _picked == null
                                    ? 'Tap to select file'
                                    : '${_picked!.name} (${_formatSize(_picked!.size)})',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _remark,
                          decoration: const InputDecoration(
                            labelText: 'Remark (optional)',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: vm.selectedProject == null ||
                                  _picked == null ||
                                  vm.uploading
                              ? null
                              : () => _upload(vm),
                          child: vm.uploading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Upload'),
                        ),
                      ],
                    ),
                  ),
                  if (vm.folderSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Storage used: ${_formatSize(vm.folderSize)}',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (vm.selectedProject != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Documents (${vm.documents.length})',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (vm.documents.isEmpty)
                      const Text('No documents uploaded for this project.',
                          style: TextStyle(color: Colors.grey)),
                    ...vm.documents.map((d) {
                      final id = PlanManagementViewModel.docIdOf(d);
                      final name = PlanManagementViewModel.docNameOf(d);
                      final remark = PlanManagementViewModel.remarkOf(d);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(name),
                          subtitle: remark == null || remark.isEmpty
                              ? null
                              : Text(remark),
                          trailing: id == null
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _editRemark(vm, id, remark),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _delete(vm, id, name),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}
