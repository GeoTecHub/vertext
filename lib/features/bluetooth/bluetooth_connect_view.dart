import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard / ClipboardData
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

// IMPORTANT: use package: import so Provider returns the SAME instance everywhere
import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';

class BluetoothConnectView extends StatefulWidget {
  const BluetoothConnectView({super.key});
  @override
  State<BluetoothConnectView> createState() => _BluetoothConnectViewState();
}

class _BluetoothConnectViewState extends State<BluetoothConnectView> {
  String? selectedAddr;
  bool _autoScroll = true;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BtViewModel>();

    // determine “receiving” if lastRxAt within last 3 seconds
    final now = DateTime.now();
    final receiving =
        bt.lastRxAt != null && now.difference(bt.lastRxAt!).inSeconds <= 3;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScroll) _scrollToBottom();
    });

    final btId = identityHashCode(bt); // <-- show the instance id

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Monitor'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('BT# $btId')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- device picker + connect controls ---
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<BluetoothDevice>>(
                    future: context.read<BtViewModel>().bondedDevices(),
                    builder: (_, snap) {
                      final list = snap.data ?? [];
                      return DropdownButton<String>(
                        value: selectedAddr,
                        hint: const Text('Pick bonded device'),
                        isExpanded: true,
                        items: list
                            .map((d) => DropdownMenuItem(
                                  value: d.address,
                                  child: Text('${d.name} (${d.address})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => selectedAddr = v),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: bt.connecting || selectedAddr == null
                      ? null
                      : () => context.read<BtViewModel>().connect(selectedAddr!),
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed:
                      bt.connected ? () => context.read<BtViewModel>().disconnect() : null,
                  child: const Text('Disconnect'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // --- status row ---
            Row(
              children: [
                Text('Status: ${bt.connecting ? "Connecting..." : (bt.connected ? "Connected" : "Disconnected")}'),
                const SizedBox(width: 12),
                Text('Receiving: ${receiving ? "Yes" : "No"}'),
                const SizedBox(width: 12),
                Text('Lines: ${bt.lineCount}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Last RX: '),
                Text(bt.lastRxAt?.toIso8601String() ?? '—'),
                const SizedBox(width: 12),
                const Text('Auto-scroll'),
                Switch(
                  value: _autoScroll,
                  onChanged: (v) => setState(() => _autoScroll = v),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --- quick parsed fields (for immediate verification) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Lat/Lon: '),
                      Text(
                        bt.currentPos != null
                            ? '${bt.currentPos!.latitude.toStringAsFixed(7)}, ${bt.currentPos!.longitude.toStringAsFixed(7)}'
                            : '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Height: '),
                      Text(bt.currentAlt?.toStringAsFixed(2) ?? '—'),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('HDOP: '),
                      Text(bt.currentHdop?.toStringAsFixed(2) ?? '—'),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Solution: '),
                      Text(
                        bt.currentSolution ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- live console ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: bt.logs.isEmpty
                    ? const Center(child: Text('No data yet'))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: bt.logs.length,
                        itemBuilder: (_, i) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            bt.logs[i],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // --- console controls ---
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: bt.logs.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(
                            ClipboardData(text: bt.logs.join('\n')),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied console to clipboard')),
                          );
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed:
                      bt.logs.isEmpty ? null : () => context.read<BtViewModel>().clearLogs(),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
