import 'package:flutter/material.dart';
import 'package:vertext_flutter/features/bluetooth/bluetooth_connect_view.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Text('Vertext', style: TextStyle(fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('BT Connect'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BluetoothConnectView()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
