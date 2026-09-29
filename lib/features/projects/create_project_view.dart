import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'create_project_viewmodel.dart';
import '../../core/models/lookup_item.dart';

class CreateProjectView extends StatefulWidget {
  const CreateProjectView({super.key});

  @override
  State<CreateProjectView> createState() => _CreateProjectViewState();
}

class _CreateProjectViewState extends State<CreateProjectView> {
  final _name = TextEditingController();
  final _projection = TextEditingController(text: 'EPSG:4326');
  final _clientName = TextEditingController();
  final _clientPhone = TextEditingController();
  final _dateStart = TextEditingController();
  final _dateEnd = TextEditingController();
  final _note = TextEditingController();
  final _assignedMemberId = TextEditingController();
  final _gndId = TextEditingController();
  final _village = TextEditingController();
  final _certifiedDate = TextEditingController();
  final _planNo = TextEditingController();
  bool _archive = false;
  bool _isPlanIssued = false;

  // Picker selections (used when lookups loaded from the API)
  String? _dsd;
  final Set<int> _gndIds = {};
  final Set<int> _memberIds = {};

  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CreateProjectViewModel>();
      vm.loadGnd(null);
      vm.loadLookups();
    });
  }

  Future<Set<int>?> _multiSelect(
      String title, List<LookupItem> items, Set<int> selected) {
    final temp = Set<int>.from(selected);
    return showDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty
                ? const Text('Nothing to select.')
                : ListView(
                    shrinkWrap: true,
                    children: items
                        .map((it) => CheckboxListTile(
                              dense: true,
                              title: Text(it.label),
                              value: temp.contains(it.id),
                              onChanged: (v) => setD(() => v == true
                                  ? temp.add(it.id!)
                                  : temp.remove(it.id)),
                            ))
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, temp),
                child: const Text('OK')),
          ],
        ),
      ),
    );
  }

  Widget _pickerField({
    required String label,
    required List<LookupItem> items,
    required Set<int> selected,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    final names = items
        .where((i) => selected.contains(i.id))
        .map((i) => i.label)
        .join(', ');
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: onTap != null,
          suffixIcon: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(names.isEmpty ? 'None selected' : names,
            style: names.isEmpty ? const TextStyle(color: Colors.grey) : null),
      ),
    );
  }

  List<Widget> _memberAndGndFields(CreateProjectViewModel vm) {
    final usePickers = vm.lookupError == null && !vm.lookupsLoading;
    if (vm.lookupsLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
      ];
    }
    if (!usePickers) {
      // Fallback: lookups unavailable (offline / API error)
      return [
        TextFormField(
          controller: _assignedMemberId,
          decoration: const InputDecoration(
              labelText: 'Assigned Member IDs (comma separated)'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _gndId,
          decoration:
              const InputDecoration(labelText: 'GND IDs (comma separated)'),
        ),
        TextButton.icon(
          onPressed: vm.loadLookups,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry loading members / GND lists'),
        ),
      ];
    }
    return [
      _pickerField(
        label: 'Assigned Members',
        items: vm.members,
        selected: _memberIds,
        onTap: () async {
          final r =
              await _multiSelect('Assign Members', vm.members, _memberIds);
          if (r != null) {
            setState(() => _memberIds
              ..clear()
              ..addAll(r));
          }
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _dsd,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'DS Division'),
        items: vm.dsdList
            .map((d) => DropdownMenuItem(value: d.value, child: Text(d.label)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _dsd = v;
            _gndIds.clear();
          });
          vm.loadGnd(v);
        },
      ),
      const SizedBox(height: 12),
      _pickerField(
        label: 'GN Divisions',
        items: vm.gndList,
        selected: _gndIds,
        busy: vm.gndLoading,
        onTap: _dsd == null || vm.gndLoading
            ? null
            : () async {
                final r =
                    await _multiSelect('GN Divisions', vm.gndList, _gndIds);
                if (r != null) {
                  setState(() => _gndIds
                    ..clear()
                    ..addAll(r));
                }
              },
      ),
    ];
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      controller.text = date.toIso8601String().split('T').first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _projection.dispose();
    _clientName.dispose();
    _clientPhone.dispose();
    _dateStart.dispose();
    _dateEnd.dispose();
    _note.dispose();
    _assignedMemberId.dispose();
    _gndId.dispose();
    _village.dispose();
    _certifiedDate.dispose();
    _planNo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateProjectViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Project')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Project Name *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientName,
              decoration: const InputDecoration(labelText: 'Client Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientPhone,
              decoration: const InputDecoration(
                  labelText: 'Client Phone (comma separated)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateStart,
                    decoration: const InputDecoration(labelText: 'Start Date'),
                    readOnly: true,
                    onTap: () => _pickDate(_dateStart),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dateEnd,
                    decoration: const InputDecoration(labelText: 'End Date'),
                    readOnly: true,
                    onTap: () => _pickDate(_dateEnd),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _projection,
              decoration: const InputDecoration(labelText: 'Projection *'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ..._memberAndGndFields(vm),
            const SizedBox(height: 12),
            TextFormField(
              controller: _village,
              decoration: const InputDecoration(labelText: 'Village'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _certifiedDate,
              decoration: const InputDecoration(labelText: 'Certified Date'),
              readOnly: true,
              onTap: () => _pickDate(_certifiedDate),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _planNo,
              decoration: const InputDecoration(labelText: 'Plan No'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Archive'),
              value: _archive,
              onChanged: (v) => setState(() => _archive = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Is Plan Issued'),
              value: _isPlanIssued,
              onChanged: (v) => setState(() => _isPlanIssued = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: vm.loading
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      
                      List<String>? clientPhoneList;
                      if (_clientPhone.text.trim().isNotEmpty) {
                        clientPhoneList = _clientPhone.text.split(',').map((e) => e.trim()).toList();
                      }
                      
                      List<int> parseIds(String t) => t
                          .split(',')
                          .map((e) => int.tryParse(e.trim()))
                          .whereType<int>()
                          .toList();
                      final pickers = vm.lookupError == null;
                      final List<int> memberIds = pickers
                          ? _memberIds.toList()
                          : parseIds(_assignedMemberId.text);
                      final List<int> gndIds = pickers
                          ? _gndIds.toList()
                          : parseIds(_gndId.text);

                      final ok = await context
                          .read<CreateProjectViewModel>()
                          .createProject(
                            name: _name.text.trim(),
                            projection: _projection.text.trim(),
                            clientName: _clientName.text.trim().isEmpty ? null : _clientName.text.trim(),
                            clientPhone: clientPhoneList,
                            dateStart: _dateStart.text.trim().isEmpty ? null : _dateStart.text.trim(),
                            dateEnd: _dateEnd.text.trim().isEmpty ? null : _dateEnd.text.trim(),
                            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                            assignedMemberId: memberIds,
                            gndId: gndIds,
                            village: _village.text.trim().isEmpty ? null : _village.text.trim(),
                            certifiedDate: _certifiedDate.text.trim().isEmpty ? null : _certifiedDate.text.trim(),
                            archive: _archive,
                            planNo: int.tryParse(_planNo.text.trim()),
                            isPlanIssued: _isPlanIssued,
                          );
                      if (ok && context.mounted) Navigator.pop(context);
                    },
              child: vm.loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
            if (vm.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(vm.error!,
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
