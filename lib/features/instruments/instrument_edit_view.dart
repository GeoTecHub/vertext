import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import 'instrument_model.dart';
import 'instrument_viewmodel.dart';

/// Used for both "Add new instrument" and "Edit existing instrument".
/// Pass [existing] to edit; omit it to add.
class InstrumentEditView extends StatefulWidget {
  final InstrumentModel? existing;
  const InstrumentEditView({super.key, this.existing});

  @override
  State<InstrumentEditView> createState() => _InstrumentEditViewState();
}

class _InstrumentEditViewState extends State<InstrumentEditView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _mfgCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _pcoCtrl;
  late final TextEditingController _btHintCtrl;

  late bool _hasTilt;
  late bool _hasSd;
  late bool _hasStatic;

  bool get _isEdit => widget.existing != null;
  bool get _isBuiltIn => widget.existing?.isBuiltIn ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mfgCtrl = TextEditingController(text: e?.manufacturer ?? '');
    _modelCtrl = TextEditingController(text: e?.model ?? '');
    _pcoCtrl = TextEditingController(
        text: e != null ? e.phaseCentreOffset.toStringAsFixed(4) : '0.0000');
    _btHintCtrl = TextEditingController(text: e?.btNameHint ?? '');
    _hasTilt = e?.hasTiltSensor ?? false;
    _hasSd = e?.hasSdCard ?? false;
    _hasStatic = e?.hasStaticMode ?? false;
  }

  @override
  void dispose() {
    _mfgCtrl.dispose();
    _modelCtrl.dispose();
    _pcoCtrl.dispose();
    _btHintCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<InstrumentViewModel>();
    final pco = double.tryParse(_pcoCtrl.text.trim()) ?? 0.0;

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        manufacturer: _isBuiltIn ? null : _mfgCtrl.text.trim(),
        model: _isBuiltIn ? null : _modelCtrl.text.trim(),
        phaseCentreOffset: pco,
        hasTiltSensor: _isBuiltIn ? null : _hasTilt,
        hasSdCard: _isBuiltIn ? null : _hasSd,
        hasStaticMode: _isBuiltIn ? null : _hasStatic,
        btNameHint: _isBuiltIn ? null : _btHintCtrl.text.trim(),
      );
      vm.updateInstrument(updated);
    } else {
      final inst = InstrumentModel(
        id: InstrumentViewModel.newId(),
        manufacturer: _mfgCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        phaseCentreOffset: pco,
        hasTiltSensor: _hasTilt,
        hasSdCard: _hasSd,
        hasStaticMode: _hasStatic,
        btNameHint: _btHintCtrl.text.trim(),
        isBuiltIn: false,
      );
      vm.addInstrument(inst);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isBuiltIn
        ? 'Edit PCO — ${widget.existing!.displayName}'
        : (_isEdit ? 'Edit Instrument' : 'Add Instrument');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kCubeBlue,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SAVE',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isBuiltIn) ...[
              // Built-in: only PCO is editable
              _SectionHeader('Phase Centre Offset'),
              const SizedBox(height: 4),
              Text(
                'ARP to L1 phase centre offset in metres.\n'
                'Applies to: Corrected Height = GNSS Alt − HI + PCO',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildPcoField(),
              const SizedBox(height: 16),
              _InfoChip(
                  icon: Icons.lock_outline,
                  text:
                      'Manufacturer, model and capabilities are locked for built-in instruments.'),
            ] else ...[
              // Custom or new: all fields editable
              _SectionHeader('Instrument Identity'),
              const SizedBox(height: 12),
              _buildTextField(
                ctrl: _mfgCtrl,
                label: 'Manufacturer',
                hint: 'e.g. Trimble, Leica, Topcon',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                ctrl: _modelCtrl,
                label: 'Model',
                hint: 'e.g. R10, GS18, HiPer VR',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _SectionHeader('Phase Centre Offset (PCO)'),
              const SizedBox(height: 4),
              Text(
                'ARP to L1 phase centre offset in metres (from IGS ANTEX).\n'
                'Use 0.0 if unknown.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildPcoField(),
              const SizedBox(height: 20),

              _SectionHeader('Capabilities'),
              const SizedBox(height: 8),
              _CapabilityTile(
                icon: Icons.screen_rotation,
                label: 'Tilt Sensor',
                subtitle: 'Has IMU for pole tilt correction',
                value: _hasTilt,
                onChanged: (v) => setState(() => _hasTilt = v),
              ),
              _CapabilityTile(
                icon: Icons.sd_card_outlined,
                label: 'SD Card / Internal Storage',
                subtitle: 'Supports raw data logging',
                value: _hasSd,
                onChanged: (v) => setState(() => _hasSd = v),
              ),
              _CapabilityTile(
                icon: Icons.fiber_manual_record_outlined,
                label: 'Static Observation Mode',
                subtitle: 'Supports static GNSS sessions',
                value: _hasStatic,
                onChanged: (v) => setState(() => _hasStatic = v),
              ),
              const SizedBox(height: 20),

              _SectionHeader('Bluetooth Name Hint'),
              const SizedBox(height: 4),
              Text(
                'Partial BT device name for auto-match (optional).',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                ctrl: _btHintCtrl,
                label: 'BT Name Hint',
                hint: 'e.g. R10, HiPer',
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPcoField() {
    return TextFormField(
      controller: _pcoCtrl,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: false),
      decoration: const InputDecoration(
        labelText: 'PCO (metres)',
        hintText: '0.0000',
        border: OutlineInputBorder(),
        suffixText: 'm',
        prefixIcon: Icon(Icons.height),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: kCubeBlue,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CapabilityTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: kCubeIconGray),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle:
          Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      activeThumbColor: kCubeBlue,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kCubeBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kCubeBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kCubeBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: kCubeBlue, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
