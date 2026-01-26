import 'package:flutter/material.dart';
import '../features/layers/layers_view.dart';
import '../features/projects/projects_view.dart';
import '../features/ntrip/ntrip_caster_view.dart';
import '../features/bluetooth/bluetooth_connect_view.dart';
import '../features/plans/plan_management_view.dart';
import '../core/storage/session_manager.dart';
import '../features/auth/login_view.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    await SessionManager().clear();
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
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MENU',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Logged in', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),

            // Data
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('Layers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LayersView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Projects'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProjectsView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Plan Management'),
              subtitle: const Text('Upload survey data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PlanManagementView()));
              },
            ),

            const Divider(),

            // GNSS / Connectivity
            ListTile(
              leading: const Icon(Icons.cast_connected),
              title: const Text('NTRIP Caster'),
              subtitle: const Text('Fetch mountpoints & connect'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NtripCasterView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Bluetooth GNSS'),
              subtitle: const Text('Pair & stream NMEA/JSON'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BluetoothConnectView()));
              },
            ),

            const Divider(),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
