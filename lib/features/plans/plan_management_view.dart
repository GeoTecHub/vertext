import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'plan_management_viewmodel.dart';
import '../../core/models/project.dart';

class PlanManagementView extends StatelessWidget {
  const PlanManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    // We can provide the VM here locally if it's not global,
    // but the plan said to make it global.
    // If it's global, we just watch it.
    // If we want a fresh instance every time, we wrap with ChangeNotifierProvider here.
    // Given the plan to add to main.dart, we'll assume it's available or we can wrap it.
    // Let's use a local provider for this screen to ensure fresh state on entry,
    // unless the user wants state persistence across navigations.
    // For "management" screens, fresh state is usually safer.
    // BUT the plan said "Register PlanManagementViewModel in the MultiProvider".
    // So let's consume it.

    final vm = context.watch<PlanManagementViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Management'),
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    value: vm.selectedProject,
                    hint: const Text('Choose a project...'),
                    isExpanded: true,
                    items: vm.projects.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.projectName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      vm.selectProject(val);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Upload Survey Data',
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
                        Icon(Icons.cloud_upload_outlined,
                            size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        const Text('Tap to select file'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: vm.selectedProject == null
                              ? null
                              : () {
                                  // Mock upload
                                  vm.uploadPlan("New Plan");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Mock upload started...')),
                                  );
                                },
                          child: const Text('Upload'),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Center(
                    child: Text(
                      'Supported formats: .csv, .dxf',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
