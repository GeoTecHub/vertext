import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../tolerance_viewmodel.dart';

class ToleranceSettingsView extends StatelessWidget {
  const ToleranceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tolerance Setting",
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.5,
      ),
      body: Consumer<ToleranceViewModel>(
        builder: (context, vm, _) {
          return ListView(
            children: [
              _buildItem(context, "Solution", vm.solution,
                  (val) => vm.update(solution: val),
                  options: ["FIXED", "FLOAT", "DGNSS", "SINGLE"]),

              _buildItem(context, "HRMS", "${vm.hrms}m",
                  (val) => vm.update(hrms: double.tryParse(val))),
              _buildItem(context, "VRMS", "${vm.vrms}m",
                  (val) => vm.update(vrms: double.tryParse(val))),
              _buildItem(context, "PDOP", "${vm.pdop}",
                  (val) => vm.update(pdop: double.tryParse(val))),
              _buildItem(context, "AGE", "${vm.age}s",
                  (val) => vm.update(age: double.tryParse(val))),

              const Divider(),

              _buildItem(context, "Used Satellites", "Unlimited",
                  null), // Not impl yet
              _buildItem(context, "Tilt Angle", "Unlimited", null),
              _buildItem(context, "Dist. to Ref", "Unlimited", null),

              _buildHeader("Average"),
              _buildItem(context, "Survey Delay", "${vm.surveyDelay}s",
                  null), // Not impl yet
              _buildItem(context, "Average Points", "${vm.averagePoints}",
                  (val) => vm.update(averagePoints: int.tryParse(val))),
              _buildItem(context, "Horizontal", "0.02m", null),
              _buildItem(context, "Vertical", "0.03m", null),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.indigo[50],
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E))),
    );
  }

  Widget _buildItem(BuildContext context, String label, String value,
      Function(String)? onSave,
      {List<String>? options}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 16, color: Colors.black)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
      onTap: onSave == null
          ? null
          : () {
              if (options != null) {
                _showOptionsDialog(context, label, options, onSave);
              } else {
                _showEditDialog(context, label,
                    value.replaceAll('m', '').replaceAll('s', ''), onSave);
              }
            },
    );
  }

  void _showEditDialog(BuildContext context, String title, String initial,
      Function(String) onSave) {
    final ctrl = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                onSave(ctrl.text);
                Navigator.pop(context);
              },
              child: const Text("Save")),
        ],
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, String title,
      List<String> options, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text("Select $title"),
        children: options
            .map((o) => SimpleDialogOption(
                  padding: const EdgeInsets.all(16),
                  child: Text(o, style: const TextStyle(fontSize: 18)),
                  onPressed: () {
                    onSave(o);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
}
