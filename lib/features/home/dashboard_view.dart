import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_drawer.dart';
import 'survey_view.dart';
import '../bluetooth/bluetooth_connect_view.dart';
import '../ntrip/ntrip_caster_view.dart';
import '../projects/projects_view.dart';
import '../projects/points_list_view.dart';
import '../layers/layers_view.dart';
import '../plans/plan_management_view.dart';
import '../../features/projects/projects_viewmodel.dart';
import '../../core/repository/auth_repository.dart';
import '../auth/login_view.dart';
import '../../features/tools/calculator_view.dart';
import '../../features/tools/coordinate_to_direction_screen.dart';
import '../../features/tools/sticky_notes_screen.dart';
import '../../features/tools/unit_converter_screen.dart';
import 'widgets/home_header.dart';
import '../setting_out/setting_out_view.dart';
import '../setting_out/line_stakeout_view.dart';
import '../sdcard/sdcard_view.dart';
import '../static_obs/static_observation_view.dart';
import '../instruments/instrument_list_view.dart';
import '../instruments/instrument_viewmodel.dart';
import '../bluetooth/bt_viewmodel.dart';
import '../gnss/gnss_live_viewmodel.dart';
import '../../app.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    // Wire BT data → GnssLiveViewModel immediately so HomeHeader always has data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bt   = context.read<BtViewModel>();
      final gnss = context.read<GnssLiveViewModel>();
      bt.onLine  = gnss.updateFromLine;
    });
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginView()),
        (_) => false,
      );
    }
  }

  // ── Tab content builders ─────────────────────────────────────────────

  Widget _buildProjectTab(BuildContext context) {
    return _CubeGrid(tiles: [
      _CubeTile(
        icon: Icons.create_new_folder_outlined,
        label: 'Project\nManager',
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProjectsView())),
      ),
      _CubeTile(
        icon: Icons.storage_outlined,
        label: 'Point\nDatabase',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PointsListView())),
      ),
      _CubeTile(
        icon: Icons.layers_outlined,
        label: 'Layers',
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LayersView())),
      ),
      _CubeTile(
        icon: Icons.map_outlined,
        label: 'Plan\nManagement',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PlanManagementView())),
      ),
      _CubeTile(
        icon: Icons.logout,
        label: 'Log Out',
        onTap: _logout,
      ),
    ]);
  }

  Widget _buildDeviceTab(BuildContext context) {
    final instrVM = context.watch<InstrumentViewModel>();
    final instrName = instrVM.selected.displayName;

    return ListView(
      children: [
        // ── Active instrument banner ─────────────────────────────────────
        InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InstrumentListView())),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kCubeDarkNavy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.satellite_alt,
                    color: Colors.white70, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Active Instrument',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      Text(
                        instrName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      Text(
                        'PCO: ${instrVM.selected.phaseCentreOffset.toStringAsFixed(4)} m',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kCubeBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('CHANGE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
              ],
            ),
          ),
        ),

        // ── Device function grid (shrinkWrap so it fits inside ListView) ─
        _CubeGrid(
          shrinkWrap: true,
          tiles: [
            _CubeTile(
              icon: Icons.devices_other_outlined,
              label: 'Instrument\nModel',
              accentBlue: true,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InstrumentListView())),
            ),
            _CubeTile(
              icon: Icons.bluetooth_connected,
              label: 'Communication',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BluetoothConnectView())),
            ),
            _CubeTile(
              icon: Icons.settings_input_antenna,
              label: 'Rover /\nNTRIP',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const NtripCasterView())),
            ),
            _CubeTile(
              icon: Icons.sd_card_outlined,
              label: 'SD Card',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SdCardView())),
            ),
            _CubeTile(
              icon: Icons.fiber_manual_record_outlined,
              label: 'Static\nObservation',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StaticObservationView())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSurveyTab(BuildContext context) {
    return _CubeGrid(tiles: [
      _CubeTile(
        icon: Icons.my_location,
        label: 'Point\nSurvey',
        accentBlue: true,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SurveyView())),
      ),
      _CubeTile(
        icon: Icons.push_pin_outlined,
        label: 'Point\nStakeout',
        accentBlue: true,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingOutView())),
      ),
      _CubeTile(
        icon: Icons.timeline,
        label: 'Line\nStakeout',
        accentBlue: true,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LineStakeoutView())),
      ),
    ]);
  }

  Widget _buildToolsTab(BuildContext context) {
    return _CubeGrid(tiles: [
      _CubeTile(
        icon: Icons.calculate_outlined,
        label: 'Calculator',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SimpleCalculator())),
      ),
      _CubeTile(
        icon: Icons.swap_horiz,
        label: 'Unit\nConverter',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const UnitConverterScreen())),
      ),
      _CubeTile(
        icon: Icons.explore_outlined,
        label: 'Coord\nConverter',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CoordinateToDirectionScreen())),
      ),
      _CubeTile(
        icon: Icons.sticky_note_2_outlined,
        label: 'Sticky\nNotes',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StickyNotesScreen())),
      ),
    ]);
  }

  static const _navItems = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Project'),
    _NavItem(icon: Icons.router_outlined, activeIcon: Icons.router, label: 'Device'),
    _NavItem(
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on,
        label: 'Survey'),
    _NavItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: 'Tools'),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildProjectTab(context),
      _buildDeviceTab(context),
      _buildSurveyTab(context),
      _buildToolsTab(context),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // GNSS status + coordinate bar
            const HomeHeader(showBackButton: false),

            // Project name bar
            const _ProjectNameBar(),

            // Content
            Expanded(child: tabs[_currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: _CubeBottomNav(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Project name bar ─────────────────────────────────────────────────────────

class _ProjectNameBar extends StatelessWidget {
  const _ProjectNameBar();

  @override
  Widget build(BuildContext context) {
    final name = context.watch<ProjectsViewModel>().selectedProjectName;
    return Container(
      width: double.infinity,
      color: kCubeBlue,
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(
        'Project: $name',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Cube grid container ───────────────────────────────────────────────────────

class _CubeGrid extends StatelessWidget {
  final List<_CubeTile> tiles;
  final bool shrinkWrap;

  const _CubeGrid({required this.tiles, this.shrinkWrap = false});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 0,
      childAspectRatio: 0.85,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: tiles,
    );
  }
}

// ── Individual Cube menu tile ─────────────────────────────────────────────────

class _CubeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accentBlue;

  const _CubeTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentBlue = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accentBlue ? kCubeIconBlue : kCubeIconGray;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        splashColor: kCubeBlue.withValues(alpha: 0.12),
        highlightColor: kCubeBlue.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF212121),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav item descriptor ───────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}

// ── Cube-style bottom navigation ──────────────────────────────────────────────

class _CubeBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _CubeBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCubeDarkNavy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    color: active ? kCubeNavActive : Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? item.activeIcon : item.icon,
                          color: active ? Colors.white : Colors.white60,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white60,
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
