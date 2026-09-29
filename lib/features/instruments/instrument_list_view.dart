import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import 'instrument_model.dart';
import 'instrument_viewmodel.dart';
import 'instrument_edit_view.dart';

class InstrumentListView extends StatelessWidget {
  const InstrumentListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InstrumentViewModel>();
    final instruments = vm.instruments;
    final selected = vm.selected;

    final builtIns = instruments.where((i) => i.isBuiltIn).toList();
    final custom = instruments.where((i) => !i.isBuiltIn).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kCubeBlue,
        foregroundColor: Colors.white,
        title: const Text('Instrument Model',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          // ── Active instrument banner ───────────────────────────────
          Container(
            color: kCubeDarkNavy,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.satellite_alt,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Active Instrument',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      Text(
                        selected.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCubeBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PCO ${selected.phaseCentreOffset.toStringAsFixed(4)} m',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              children: [
                // ── Built-in section ─────────────────────────────────
                _SectionHeader(
                    'DEFAULT INSTRUMENTS', Icons.verified_outlined),

                ...builtIns.map((inst) => _InstrumentTile(
                      inst: inst,
                      isSelected: inst.id == selected.id,
                      onTap: () => vm.select(inst.id),
                      onEdit: () => _openEdit(context, inst),
                    )),

                // ── Custom section ────────────────────────────────────
                _SectionHeader(
                    'CUSTOM INSTRUMENTS', Icons.tune_outlined),

                if (custom.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      'No custom instruments added yet.\nTap + to add one.',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13),
                    ),
                  ),

                ...custom.map((inst) => _InstrumentTile(
                      inst: inst,
                      isSelected: inst.id == selected.id,
                      onTap: () => vm.select(inst.id),
                      onEdit: () => _openEdit(context, inst),
                      onDelete: () => _confirmDelete(context, vm, inst),
                    )),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kCubeBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Instrument',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () => _openAdd(context),
      ),
    );
  }

  void _openAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InstrumentEditView()),
    );
  }

  void _openEdit(BuildContext context, InstrumentModel inst) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => InstrumentEditView(existing: inst)),
    );
  }

  void _confirmDelete(
      BuildContext context, InstrumentViewModel vm, InstrumentModel inst) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Instrument'),
        content: Text(
            'Remove "${inst.displayName}" from the list?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteInstrument(inst.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: kCubeNoFixRed)),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Icon(icon, color: kCubeBlue, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: kCubeBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual instrument row ─────────────────────────────────────────────────

class _InstrumentTile extends StatelessWidget {
  final InstrumentModel inst;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _InstrumentTile({
    required this.inst,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? kCubeBlue.withValues(alpha: 0.07)
            : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Selection indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? kCubeBlue : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? kCubeBlue : Colors.grey[400]!,
                        width: isSelected ? 0 : 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // Name + PCO + chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              inst.displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? kCubeBlue
                                    : const Color(0xFF212121),
                              ),
                            ),
                            if (inst.isBuiltIn) ...[
                              const SizedBox(width: 6),
                              _Tag('Built-in', kCubeBlue),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _PcoChip(inst.phaseCentreOffset),
                            if (inst.hasTiltSensor)
                              _CapChip(Icons.screen_rotation, 'Tilt'),
                            if (inst.hasSdCard)
                              _CapChip(Icons.sd_card_outlined, 'SD'),
                            if (inst.hasStaticMode)
                              _CapChip(Icons.fiber_manual_record_outlined,
                                  'Static'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: kCubeIconGray),
                    tooltip: inst.isBuiltIn ? 'Edit PCO' : 'Edit',
                    onPressed: onEdit,
                  ),

                  // Delete (custom only)
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: kCubeNoFixRed),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                    ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 52),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _PcoChip extends StatelessWidget {
  final double pco;
  const _PcoChip(this.pco);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'PCO ${pco.toStringAsFixed(4)} m',
        style: TextStyle(
            color: Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CapChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: kCubeBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: kCubeBlue),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color: kCubeBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
