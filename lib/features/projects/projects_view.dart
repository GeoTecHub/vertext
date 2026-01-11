import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/project.dart';
import 'projects_viewmodel.dart';

class ProjectsView extends StatefulWidget {
  const ProjectsView({super.key});
  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProjectsViewModel>().refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProjectsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: vm.loading
          ? const LinearProgressIndicator()
          : ListView.separated(
              itemCount: vm.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = vm.items[i];
                return ListTile(
                  title: Text(p.projectName),
                  subtitle:
                      Text('Projection: ${p.projection} • Date: ${p.dateCreated}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(context, vm, p),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
      BuildContext ctx, ProjectsViewModel vm, ProjectModel p) async {
    final name = TextEditingController(text: p.projectName);
    final proj = TextEditingController(text: p.projection);
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Edit Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: proj, decoration: const InputDecoration(labelText: 'Projection')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await vm.update(p, name: name.text, projection: proj.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
