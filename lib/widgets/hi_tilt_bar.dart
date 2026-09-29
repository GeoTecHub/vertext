import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/bluetooth/bt_viewmodel.dart';

/// Compact bar shown under the info bar in Survey / Stakeout views.
/// Displays live tilt angle with colour coding and lets the user edit HI inline.
class HiTiltBar extends StatelessWidget {
  const HiTiltBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BtViewModel>();

    final tilt    = bt.totalTilt;
    final roll    = bt.currentRoll;
    final pitch   = bt.currentPitch;
    final hasTilt = bt.tiltEnabled && (roll != null || pitch != null);

    final Color tiltColor = tilt > 5.0
        ? Colors.red
        : tilt > 2.0
            ? Colors.orange
            : Colors.green;

    return Container(
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          // ── Tilt indicator ───────────────────────────────────────────────
          if (hasTilt) ...[
            Icon(Icons.screen_rotation, size: 14, color: tiltColor),
            const SizedBox(width: 4),
            Text(
              '${tilt.toStringAsFixed(1)}°',
              style: TextStyle(
                  color: tiltColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const SizedBox(width: 6),
            Text(
              'R:${roll!.toStringAsFixed(1)}°  P:${pitch!.toStringAsFixed(1)}°',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            if (tilt > 3.0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('TILT!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ] else ...[
            const Icon(Icons.screen_rotation_outlined,
                size: 14, color: Colors.white38),
            const SizedBox(width: 4),
            const Text('Tilt —',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],

          const Spacer(),

          // ── HI display + edit button ─────────────────────────────────────
          GestureDetector(
            onTap: () => _showHiEditor(context, bt),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.white24)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.height, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    'HI: ${bt.correctedHI.toStringAsFixed(3)} m',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12, color: Colors.white54),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Public alias so other widgets can open the same editor.
  void showHiEditorPublic(BuildContext context, BtViewModel bt) =>
      _showHiEditor(context, bt);

  void _showHiEditor(BuildContext context, BtViewModel bt) {
    final poleCtrl = TextEditingController(
        text: bt.poleHeight.toStringAsFixed(3));
    final rodCtrl  = TextEditingController(
        text: bt.rodHeight.toStringAsFixed(3));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(children: [
              const Icon(Icons.height, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              const Text('Height of Instrument',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3A8A))),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            Text(
              'Device: ${bt.selectedDevice.displayName}  '
              '•  Phase centre offset: '
              '${bt.selectedDevice.phaseCentreOffset.toStringAsFixed(4)} m',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 20),

            // Pole height
            _HiField(
              label: 'Pole / Antenna Height (m)',
              hint: 'Measured from ground mark to ARP',
              ctrl: poleCtrl,
              icon: Icons.straighten,
            ),
            const SizedBox(height: 12),

            // Rod height
            _HiField(
              label: 'Rod / Tribrach Additional Height (m)',
              hint: 'Extra height from extension, if any',
              ctrl: rodCtrl,
              icon: Icons.vertical_align_top,
            ),
            const SizedBox(height: 16),

            // Live preview
            _StatefulPreview(
              poleCtrl: poleCtrl,
              rodCtrl: rodCtrl,
              bt: bt,
            ),
            const SizedBox(height: 16),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.check),
                label: const Text('Apply',
                    style: TextStyle(fontSize: 16)),
                onPressed: () {
                  final pole = double.tryParse(poleCtrl.text);
                  final rod  = double.tryParse(rodCtrl.text);
                  if (pole != null && pole >= 0) bt.poleHeight = pole;
                  if (rod  != null && rod  >= 0) bt.rodHeight  = rod;
                  bt.notifyHiChanged();
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact HI/tilt row for use inside toolbar panels ────────────────────────
class HiStatusRow extends StatelessWidget {
  const HiStatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    final bt    = context.watch<BtViewModel>();
    final hi    = bt.correctedHI;
    final corrH = bt.correctedEllipsoidHeight;
    final tilt  = bt.totalTilt;
    final showTilt = bt.tiltEnabled && bt.currentRoll != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _chip(Icons.height, 'HI', '${hi.toStringAsFixed(3)} m'),
          if (corrH != null)
            _chip(Icons.place, 'Gnd H', '${corrH.toStringAsFixed(3)} m'),
          if (showTilt)
            _chip(
              Icons.screen_rotation,
              'Tilt',
              '${tilt.toStringAsFixed(1)}°',
              color: tilt > 3.0 ? Colors.red : Colors.green,
            ),
          // Edit button
          GestureDetector(
            onTap: () {
              final bar = const HiTiltBar();
              bar.showHiEditorPublic(context, bt);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(5)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text('HI', style: TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value, {Color? color}) {
    final c = color ?? const Color(0xFF1E3A8A);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 3),
      Column(children: [
        Text(label,
            style: TextStyle(fontSize: 9, color: c.withValues(alpha: 0.7))),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: c)),
      ]),
    ]);
  }
}

class _HiField extends StatelessWidget {
  const _HiField(
      {required this.label,
      required this.hint,
      required this.ctrl,
      required this.icon});
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixText: 'm',
      ),
    );
  }
}

/// Shows a live-updating corrected HI preview as user types.
class _StatefulPreview extends StatefulWidget {
  const _StatefulPreview(
      {required this.poleCtrl, required this.rodCtrl, required this.bt});
  final TextEditingController poleCtrl;
  final TextEditingController rodCtrl;
  final BtViewModel bt;

  @override
  State<_StatefulPreview> createState() => _StatefulPreviewState();
}

class _StatefulPreviewState extends State<_StatefulPreview> {
  @override
  void initState() {
    super.initState();
    widget.poleCtrl.addListener(_rebuild);
    widget.rodCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.poleCtrl.removeListener(_rebuild);
    widget.rodCtrl.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pole = double.tryParse(widget.poleCtrl.text) ?? widget.bt.poleHeight;
    final rod  = double.tryParse(widget.rodCtrl.text)  ?? widget.bt.rodHeight;
    final hi   = pole + rod;
    final pco  = widget.bt.selectedDevice.phaseCentreOffset;
    final alt  = widget.bt.currentAlt;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[100]!)),
      child: Column(
        children: [
          _previewRow('Total HI', '${hi.toStringAsFixed(4)} m'),
          _previewRow('Phase centre offset', '${pco.toStringAsFixed(4)} m'),
          if (alt != null)
            _previewRow('Corrected ground height',
                '${(alt - hi + pco).toStringAsFixed(4)} m',
                bold: true),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700], fontSize: 12)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: bold
                      ? const Color(0xFF1E3A8A)
                      : Colors.black87,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
