import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'points_viewmodel.dart';
import '../../core/models/point.dart';
import '../../utils/sld99_converter.dart';
import 'point_details_card.dart';

import '../../features/projects/projects_viewmodel.dart';

class PointsListView extends StatefulWidget {
  const PointsListView({super.key});

  @override
  State<PointsListView> createState() => _PointsListViewState();
}

class _PointsListViewState extends State<PointsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncProject();
    });
  }

  void _syncProject() {
    final projectsVM = context.read<ProjectsViewModel>();
    final pointsVM = context.read<PointsViewModel>();

    final selectedId = projectsVM.selectedProjectId;
    final currentId = pointsVM.getProjectId();

    // If IDs match, do nothing (unless forced refresh needed?)
    // If IDs differ, load new.
    if (selectedId != null && selectedId != currentId) {
      pointsVM.load(selectedId);
    } else if (selectedId == null) {
      // Maybe clear points or show empty?
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PointsViewModel>();
    // Watch projects to trigger rebuild/sync if selection changes while this view is open (unlikely if strictly push/pop, but good practice)
    // final projectVM = context.watch<ProjectsViewModel>();

    // We can also trigger load if build detects mismatch, but initState is cleaner for initial.
    // However, if we change project in another tab and come back?
    // Since we push this view, initState works.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collected Points'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0),
          child: Container(
            color: Colors.grey[200],
            width: double.infinity,
            padding: const EdgeInsets.all(4.0),
            child: Text(
              'Project ID: ${vm.points.isNotEmpty ? vm.points.first.projectId : (vm.getProjectId() ?? "Unknown")}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Send to Backend',
            icon: const Icon(Icons.cloud_upload),
            onPressed: vm.points.isEmpty
                ? null
                : () async {
                    try {
                      final r = await vm.sendData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(r.message),
                            backgroundColor:
                                r.hasProblems ? Colors.orange.shade800 : null,
                            duration: Duration(
                                seconds: r.hasProblems ? 8 : 3),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Send failed: $e')),
                        );
                      }
                    }
                  },
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.share),
            onPressed: vm.points.isEmpty
                ? null
                : () async {
                    try {
                      final path = await vm.exportCsv();
                      // ignore: deprecated_member_use
                      await Share.shareXFiles([XFile(path)],
                          text: 'Collected Points CSV');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    }
                  },
          ),
        ],
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.points.isEmpty
              ? const Center(child: Text('No points collected yet.'))
              : ListView.separated(
                  itemCount: vm.points.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = vm.points[i];
                    return ListTile(
                      leading: Tooltip(
                        message: p.pendingSync
                            ? 'Change waiting to upload'
                            : p.fromServer
                            ? 'From server${p.doneBy != null ? ' (${p.doneBy})' : ''}'
                            : p.serverId != null
                                ? 'Sent'
                                : 'Not sent',
                        child: Icon(
                          p.pendingSync
                              ? Icons.cloud_upload
                              : p.fromServer
                                  ? Icons.cloud_download
                                  : p.serverId != null
                                      ? Icons.cloud_done
                                      : Icons.cloud_off,
                          color: p.pendingSync
                              ? Colors.orange
                              : p.fromServer
                                  ? Colors.blue
                                  : p.serverId != null
                                      ? Colors.green
                                      : Colors.grey,
                          size: 20,
                        ),
                      ),
                      title: Text('Point No: ${p.name}'
                          '${(p.code ?? '').isEmpty ? '' : '  •  ${p.code}'}'
                          '${p.fromServer && p.doneBy != null ? '  •  ${p.doneBy}' : ''}'),
                      subtitle: Builder(builder: (_) {
                        final sld = Sld99Converter.toSld99(p.latitude, p.longitude);
                        return Text(
                            '${p.latitude.toStringAsFixed(7)}, ${p.longitude.toStringAsFixed(7)}\n'
                            'E ${sld['easting']!.toStringAsFixed(3)}  N ${sld['northing']!.toStringAsFixed(3)}  '
                            'Z ${p.altitude?.toStringAsFixed(2) ?? "--"}');
                      }),
                      onTap: () => showPointDetails(context, p),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(context, vm, p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, vm, p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, PointsViewModel vm, PointModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete point ${p.name}?'),
        content: Text(p.serverId != null
            ? 'This point will also be deleted from the server.'
            : 'This point has not been sent and will be removed from this device.'),
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
    if (ok != true) return;
    try {
      await vm.deletePoint(p.id!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _showEditDialog(
      BuildContext context, PointsViewModel vm, dynamic point) {
    // Determine initial values
    // If name is empty or we want to auto-increment, do it here?
    // Actually, user said "replace with name with point no increment"
    // So if editing, we keep existing or suggest update?
    // Let's pre-fill with existing data.

    final nameController = TextEditingController(text: point.name);
    final codeController = TextEditingController(text: point.code ?? '');
    final heightController =
        TextEditingController(text: point.instrumentHeight?.toString() ?? '');

    // Recent codes for suggestions
    final recentCodes = vm.getRecentCodes();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Point'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: nameController,
                builder: (_, v, __) {
                  final st = vm.checkPointNumber(v.text, excludeId: point.id);
                  return TextField(
                    controller: nameController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Point No',
                      errorText: st.isTaken ? st.label : null,
                      helperText: st.isTaken ? null : st.label,
                      helperStyle: TextStyle(
                          color: st == PointNoStatus.available
                              ? Colors.green
                              : Colors.grey),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // Code with suggestions
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return recentCodes;
                  return recentCodes.where((c) => c
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (option) => codeController.text = option,
                fieldViewBuilder: (ctx, controller, focus, onSubmitted) {
                  // Sync local controller if needed, or use this one
                  if (controller.text != codeController.text) {
                    controller.text = codeController.text;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(labelText: 'Code'),
                    onChanged: (v) => codeController.text = v,
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: heightController,
                decoration:
                    const InputDecoration(labelText: 'Instrument Height'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final st = await vm.verifyPointNumber(nameController.text,
                  excludeId: point.id);
              if (st.isTaken || st == PointNoStatus.invalid) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Point No ${nameController.text}: ${st.label}')));
                }
                return;
              }
              // Update point
              point.name = nameController.text.trim();
              point.code = codeController.text;
              point.instrumentHeight =
                  double.tryParse(heightController.text) ??
                      point.instrumentHeight;

              try {
                await vm.updatePoint(point); // Save locally (+ server)
                if (context.mounted && point.serverId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Point ${point.name} updated on the server.')));
                }
              } on PointSyncException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.message),
                    backgroundColor: e.willRetry
                        ? Colors.orange.shade800
                        : Colors.red.shade700,
                    duration: const Duration(seconds: 6),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Save failed: $e')));
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
