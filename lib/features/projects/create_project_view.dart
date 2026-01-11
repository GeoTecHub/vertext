import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'create_project_viewmodel.dart';

class CreateProjectView extends StatefulWidget {
  const CreateProjectView({super.key});

  @override
  State<CreateProjectView> createState() => _CreateProjectViewState();
}

class _CreateProjectViewState extends State<CreateProjectView> {
  final _name = TextEditingController();
  final _projection = TextEditingController(text: 'EPSG:4326');
  final _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateProjectViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Project')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Project Name'),
                validator: (v) => (v==null||v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _projection,
                decoration: const InputDecoration(labelText: 'Projection'),
                validator: (v) => (v==null||v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: vm.loading ? null : () async {
                  if (!_form.currentState!.validate()) return;
                  final ok = await context.read<CreateProjectViewModel>()
                      .createProject(name: _name.text.trim(), projection: _projection.text.trim());
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: vm.loading ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
              ),
              if (vm.error != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(vm.error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
