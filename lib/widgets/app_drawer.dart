import 'package:flutter/material.dart';
import '../features/layers/layers_view.dart';
import '../features/projects/projects_view.dart';
import '../features/ntrip/ntrip_caster_view.dart';
import '../features/bluetooth/bluetooth_connect_view.dart';
import '../features/plans/plan_management_view.dart';
import '../features/projects/points_list_view.dart';
import '../core/repository/auth_repository.dart';
import '../features/auth/login_view.dart';
import '../app.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthRepository().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginView()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D2D54),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: kCubeBlue,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.satellite_alt,
                        color: kCubeBlue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VerText',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1),
                      ),
                      Text(
                        'GNSS Field Survey',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _DrawerSection('DATA'),
                  _DrawerItem(
                    icon: Icons.layers_outlined,
                    title: 'Layers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LayersView()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.create_new_folder_outlined,
                    title: 'Projects',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProjectsView()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.map_outlined,
                    title: 'Plan Management',
                    subtitle: 'Upload survey data',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlanManagementView()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.list_alt_outlined,
                    title: 'Collected Points',
                    subtitle: 'View and manage points',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PointsListView()));
                    },
                  ),

                  _DrawerSection('CONNECTIVITY'),
                  _DrawerItem(
                    icon: Icons.cell_tower,
                    title: 'NTRIP Caster',
                    subtitle: 'Fetch mountpoints & connect',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NtripCasterView()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.bluetooth_outlined,
                    title: 'Bluetooth GNSS',
                    subtitle: 'Pair & stream NMEA/JSON',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BluetoothConnectView()));
                    },
                  ),

                  const Divider(color: Colors.white12, indent: 16, endIndent: 16),

                  _DrawerItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 8,
      splashColor: kCubeBlue.withValues(alpha: 0.2),
    );
  }
}
