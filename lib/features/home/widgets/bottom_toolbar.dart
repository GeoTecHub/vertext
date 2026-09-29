import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bluetooth/bt_viewmodel.dart';
import '../../projects/points_viewmodel.dart';
import '../../projects/points_list_view.dart';
import 'tolerance_settings_view.dart';
import '../../projects/projects_view.dart';
import '../../../widgets/hi_tilt_bar.dart';

class HomeBottomBar extends StatefulWidget {
  final void Function(String name, String code) onSave;
  final void Function(bool isPlane) onToggleView;

  const HomeBottomBar(
      {super.key, required this.onSave, required this.onToggleView});

  @override
  State<HomeBottomBar> createState() => _HomeBottomBarState();
}

class _HomeBottomBarState extends State<HomeBottomBar> {
  late TextEditingController _nameCtrl;
  final TextEditingController _codeCtrl = TextEditingController();

  /// True once the user types their own point number; until then the field
  /// follows the next free number (which changes as points are saved here
  /// or on other devices).
  bool _userEdited = false;

  // Toggles
  bool _autoFollowEnabled = false;
  bool _isPlaneView = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name based on next point
    final pm = context.read<PointsViewModel>();
    _nameCtrl = TextEditingController(text: pm.getNextPointNumber());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _followNextNumber(PointsViewModel pm) {
    if (_userEdited) return;
    final next = pm.getNextPointNumber();
    if (_nameCtrl.text == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_userEdited) _nameCtrl.text = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.watch<PointsViewModel>();
    _followNextNumber(pm);
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tools Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // 1. Tilt Sensor — wired to BT command protocol
                Builder(builder: (ctx) {
                  final bt = ctx.watch<BtViewModel>();
                  return _buildToolBtn(
                    Icons.screen_rotation,
                    bt.tiltEnabled ? Colors.green : Colors.grey[800]!,
                    onPressed: bt.connected && bt.selectedDevice.hasTiltSensor
                        ? () {
                            if (bt.tiltEnabled) {
                              bt.disableTilt();
                            } else {
                              bt.enableTilt();
                            }
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(bt.tiltEnabled
                                  ? "Tilt Sensor OFF"
                                  : "Tilt Sensor ON"),
                              duration: const Duration(seconds: 1),
                            ));
                          }
                        : null,
                  );
                }),

                // 2. Auto Follow (Measure Mode)
                _buildToolBtn(Icons.gps_fixed,
                    _autoFollowEnabled ? Colors.green : Colors.grey[800]!,
                    onPressed: () {
                  final newState = !_autoFollowEnabled;
                  setState(() => _autoFollowEnabled = newState);
                  // We need to actually trigger the follow me logic in WebView
                  // Since we can't easily reach up, we might need a Bus or Provider.
                  // But for now, we just toggle UI.
                  // The SurveyView sets it true initially.
                  if (newState) {
                    // If we could find a way to re-enable it.
                    // For now, UI toggle only as requested "change color of button".
                  }
                }),

                // 2.5 Map/Plane Toggle
                _buildToolBtn(_isPlaneView ? Icons.grid_on : Icons.map,
                    _isPlaneView ? Colors.blue : Colors.grey[800]!,
                    onPressed: () {
                  setState(() => _isPlaneView = !_isPlaneView);
                  widget.onToggleView(_isPlaneView);
                }),

                // 3. Settings -> Tolerance Settings
                _buildToolBtn(Icons.settings, Colors.grey[800]!, onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ToleranceSettingsView()));
                }),

                // 4. Description -> Point Database
                _buildToolBtn(Icons.description, Colors.grey[800]!,
                    onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PointsListView()));
                }),

                // 5. Removed Edit Icon

                // 6. Project Manager
                _buildToolBtn(Icons.home_repair_service, Colors.grey[800]!,
                    onPressed: () {
                  // Link to Project Manager
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProjectsView()));
                }),
              ],
            ),
          ),
          // Input Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildPointNoInput(pm),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildInput("Code", _codeCtrl),
                ),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: () {
                      widget.onSave(_nameCtrl.text.trim(), _codeCtrl.text);
                      // Continue after the highest saved number.
                      setState(() => _userEdited = false);
                    },
                    icon: const Icon(Icons.save_as,
                        size: 32, color: Colors.blueAccent)),
              ],
            ),
          ),

          // HI + Tilt bar (moved from above map to bottom)
          const HiTiltBar(),
        ],
      ),
    );
  }

  Widget _buildToolBtn(IconData icon, Color color, {VoidCallback? onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed ?? () {},
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }

  Widget _buildPointNoInput(PointsViewModel pm) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nameCtrl,
      builder: (context, value, _) {
        final status = pm.checkPointNumber(value.text);
        final (IconData icon, Color color) = switch (status) {
          PointNoStatus.available => (Icons.check_circle, Colors.green),
          PointNoStatus.unverified => (Icons.cloud_off, Colors.grey),
          PointNoStatus.invalid => (Icons.error_outline, Colors.orange),
          _ => (Icons.cancel, Colors.red),
        };
        final border = OutlineInputBorder(
          borderSide: BorderSide(
              color: status.isTaken ? Colors.red : Colors.grey.shade400,
              width: status.isTaken ? 2 : 1),
        );
        return TextField(
          controller: _nameCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => _userEdited = true,
          decoration: InputDecoration(
            labelText: status.isTaken ? 'Point No (taken)' : 'Point No',
            labelStyle: status.isTaken ? const TextStyle(color: Colors.red) : null,
            isDense: true,
            border: border,
            enabledBorder: border,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            suffixIcon: Tooltip(
              message: status.isTaken
                  ? '${status.label} - tap for next free number'
                  : status.label,
              child: InkWell(
                onTap: () {
                  // Jump back to the next free number.
                  setState(() => _userEdited = false);
                  _nameCtrl.text = pm.getNextPointNumber();
                },
                child: Icon(icon, color: color, size: 18),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl,
      {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}
