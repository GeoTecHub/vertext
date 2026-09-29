import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'layers_viewmodel.dart';

class LayersView extends StatefulWidget {
  const LayersView({super.key});
  @override
  State<LayersView> createState() => _LayersViewState();
}

class _LayersViewState extends State<LayersView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<LayersViewModel>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LayersViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Layers')),
      body: vm.loading
          ? const LinearProgressIndicator()
          : ListView.separated(
              itemCount: vm.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final l = vm.items[i];
                return ListTile(
                  title: Text(l.layerName),
                  subtitle: Text('Color: ${l.colour} • Visible: ${l.visible}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editLayer(
                            context, vm, l.layerId, l.layerName, l.colour)),
                    IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => vm.remove(l.layerId)),
                  ]),
                );
              }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createLayer(context, vm),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createLayer(BuildContext ctx, LayersViewModel vm) async {
    final nameCtrl = TextEditingController();
    final colourCtrl = TextEditingController(text: '#ff0000');
    await showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              title: const Text('New Layer'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: colourCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Colour (hex)')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      await vm.add(nameCtrl.text, colourCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Create')),
              ],
            ));
  }

  Future<void> _editLayer(BuildContext ctx, LayersViewModel vm, int id,
      String name, String colour) async {
    final nameCtrl = TextEditingController(text: name);
    final colourCtrl = TextEditingController(text: colour);
    await showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              title: const Text('Edit Layer'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: colourCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Colour (hex)')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      await vm.edit(id,
                          name: nameCtrl.text, colour: colourCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save')),
              ],
            ));
  }
}
