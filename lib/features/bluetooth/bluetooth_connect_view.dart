import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bt_viewmodel.dart';
import '../instruments/instrument_viewmodel.dart';
import '../instruments/instrument_list_view.dart';
import '../../app.dart';

class BluetoothConnectView extends StatefulWidget {
  const BluetoothConnectView({super.key});
  @override
  State<BluetoothConnectView> createState() => _BluetoothConnectViewState();
}

class _BluetoothConnectViewState extends State<BluetoothConnectView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ipCtrl  = TextEditingController(text: '192.168.4.1');
  final _portCtrl = TextEditingController(text: '2101');
  final _hiCtrl  = TextEditingController();
  final _rodCtrl = TextEditingController();
  final ScrollController _logScrollCtrl = ScrollController();
  bool _logsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final bt = BtViewModel.instance;
    _hiCtrl.text  = bt.poleHeight.toStringAsFixed(3);
    _rodCtrl.text = bt.rodHeight.toStringAsFixed(3);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _hiCtrl.dispose();
    _rodCtrl.dispose();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logScrollCtrl.hasClients) {
      _logScrollCtrl.animateTo(
        _logScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Instrument selector card ──────────────────────────────────────────────
  Widget _buildInstrumentCard(BtViewModel bt, InstrumentViewModel instrVM) {
    final instruments = instrVM.instruments;
    final selected = instrVM.selected;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kCubeBlue,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.satellite_alt,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Text('Instrument Model',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InstrumentListView()),
                  ),
                  child: const Text('Manage',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white70)),
                ),
              ],
            ),
          ),

          // Dropdown — always enabled (not locked by connection state)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: DropdownButtonFormField<String>(
              value: selected.id,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              isExpanded: true,
              items: instruments.map((inst) {
                return DropdownMenuItem<String>(
                  value: inst.id,
                  child: Row(
                    children: [
                      Icon(
                        inst.isBuiltIn
                            ? Icons.verified_outlined
                            : Icons.tune_outlined,
                        size: 16,
                        color: kCubeBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              inst.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            Text(
                              [
                                if (inst.hasTiltSensor) 'Tilt',
                                if (inst.hasSdCard) 'SD',
                                if (inst.hasStaticMode) 'Static',
                                'PCO: ${inst.phaseCentreOffset.toStringAsFixed(4)} m',
                              ].join('  •  '),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) {
                  instrVM.select(id);
                }
              },
            ),
          ),

          // Capability chips for selected instrument
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                if (selected.hasTiltSensor)
                  _CapChip(Icons.screen_rotation, 'Tilt Sensor', kCubeBlue),
                if (selected.hasSdCard)
                  _CapChip(Icons.sd_card_outlined, 'SD Card',
                      const Color(0xFF2E7D32)),
                if (selected.hasStaticMode)
                  _CapChip(Icons.fiber_manual_record_outlined, 'Static',
                      const Color(0xFFE65100)),
                _CapChip(
                  Icons.height,
                  'PCO ${selected.phaseCentreOffset.toStringAsFixed(4)} m',
                  Colors.grey.shade700,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Antenna height inputs
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Antenna Height',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: kCubeIconGray)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hiCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Pole Height (m)',
                          border: OutlineInputBorder(),
                          suffixText: 'm',
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            bt.poleHeight = double.tryParse(v) ?? bt.poleHeight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _rodCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Rod / Tribrach (m)',
                          border: OutlineInputBorder(),
                          suffixText: 'm',
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            bt.rodHeight = double.tryParse(v) ?? bt.rodHeight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _HiSummaryRow(bt: bt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bluetooth tab ─────────────────────────────────────────────────────────
  Widget _buildBluetoothTab(BtViewModel bt, InstrumentViewModel instrVM) {
    return ListView(
      children: [
        _buildInstrumentCard(bt, instrVM),

        if (bt.connected && !bt.isWifi) ...[
          _SectionHeader('Connected Device'),
          _ConnectedDeviceCard(bt: bt),
        ],

        _SectionHeader('Paired Devices'),
        FutureBuilder(
          future: bt.bondedDevices(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('No paired devices',
                        style: TextStyle(color: Colors.grey))),
              );
            }
            return Column(
              children: snapshot.data!.map((device) {
                final isCurrent = bt.connected && !bt.isWifi;
                return ListTile(
                  leading: Icon(Icons.bluetooth_connected,
                      color: isCurrent ? kCubeBlue : Colors.grey),
                  title: Text(device.name ?? 'Unknown'),
                  subtitle: Text(device.address),
                  trailing: bt.connecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kCubeBlue,
                              foregroundColor: Colors.white),
                          onPressed: () => bt.connect(device.address),
                          child: const Text('Connect'),
                        ),
                );
              }).toList(),
            );
          },
        ),

        const Divider(),
        _SectionHeader('Scan for Devices'),
        if (bt.isDiscovering) const LinearProgressIndicator(),
        if (bt.results.isEmpty)
          Center(
            child: TextButton.icon(
              onPressed: bt.startDiscovery,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan'),
            ),
          )
        else
          ...bt.results.map((r) => ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(r.device.name ?? 'Unknown'),
                subtitle: Text(r.device.address),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kCubeBlue,
                      foregroundColor: Colors.white),
                  onPressed: () => bt.connect(r.device.address),
                  child: const Text('Connect'),
                ),
              )),
      ],
    );
  }

  // ── WiFi tab ──────────────────────────────────────────────────────────────
  Widget _buildWiFiTab(BtViewModel bt, InstrumentViewModel instrVM) {
    return ListView(
      children: [
        _buildInstrumentCard(bt, instrVM),
        _SectionHeader('Direct TCP Connection'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _portCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kCubeBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14)),
                onPressed: () {
                  final host = _ipCtrl.text.trim();
                  final port =
                      int.tryParse(_portCtrl.text.trim()) ?? 2101;
                  bt.connectWifi(host, port);
                },
                child: const Text('Connect'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionHeader('Available WiFi Networks'),
        if (bt.isWifiScanning) const LinearProgressIndicator(),
        if (bt.wifiResults.isEmpty)
          Center(
            child: TextButton.icon(
              onPressed: bt.startWifiScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan for WiFi'),
            ),
          )
        else
          ...bt.wifiResults.map((net) => ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(net.ssid ?? 'Unknown'),
                subtitle: Text('Level: ${net.level}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kCubeBlue,
                      foregroundColor: Colors.white),
                  onPressed: () =>
                      _showWifiPasswordDialog(context, net.ssid ?? ''),
                  child: const Text('Connect'),
                ),
              )),
      ],
    );
  }

  void _showWifiPasswordDialog(BuildContext context, String ssid) {
    final passCtrl = TextEditingController(text: '12345678');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect to $ssid'),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<BtViewModel>()
                  .connectToWifiAp(ssid, password: passCtrl.text);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BtViewModel>();
    final instrVM = context.watch<InstrumentViewModel>();

    if (_logsExpanded && bt.logs.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kCubeBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Communication',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Bluetooth', icon: Icon(Icons.bluetooth, size: 18)),
            Tab(text: 'WiFi', icon: Icon(Icons.wifi, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBluetoothTab(bt, instrVM),
                _buildWiFiTab(bt, instrVM),
              ],
            ),
          ),

          // ── Log toggle ───────────────────────────────────────────────
          InkWell(
            onTap: () =>
                setState(() => _logsExpanded = !_logsExpanded),
            child: Container(
              color: kCubeDarkNavy,
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(
                      bt.connected
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 10,
                      color: bt.connected
                          ? Colors.greenAccent
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bt.connected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                    if (bt.logs.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('(${bt.logs.length} lines)',
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12)),
                    ],
                  ]),
                  Icon(
                    _logsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),

          if (_logsExpanded)
            Container(
              height: 150,
              color: Colors.black,
              child: ListView.builder(
                controller: _logScrollCtrl,
                itemCount: bt.logs.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    bt.logs[i],
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
            )
          else if (bt.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: Colors.white,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kCubeNoFixRed,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                onPressed: bt.disconnect,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      width: double.infinity,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            color: kCubeBlue,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CapChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HiSummaryRow extends StatelessWidget {
  final BtViewModel bt;
  const _HiSummaryRow({required this.bt});

  @override
  Widget build(BuildContext context) {
    final hi = bt.correctedHI;
    final h = bt.correctedEllipsoidHeight;
    return Row(
      children: [
        Expanded(
            child: _chip(
                'Corrected HI', '${hi.toStringAsFixed(4)} m')),
        const SizedBox(width: 8),
        Expanded(
            child: _chip('Ellipsoid H',
                h != null ? '${h.toStringAsFixed(4)} m' : '—')),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
          color: kCubeBlue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: kCubeBlue)),
      ]),
    );
  }
}

class _ConnectedDeviceCard extends StatelessWidget {
  final BtViewModel bt;
  const _ConnectedDeviceCard({required this.bt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kCubeBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth_connected,
                size: 24, color: kCubeBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bt.selectedDevice.displayName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  bt.currentSolution ?? 'Waiting for data...',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          if (bt.selectedDevice.hasTiltSensor)
            IconButton(
              icon: Icon(
                bt.tiltEnabled
                    ? Icons.screen_rotation
                    : Icons.screen_rotation_outlined,
                color: bt.tiltEnabled ? Colors.green : Colors.grey,
              ),
              tooltip: bt.tiltEnabled ? 'Tilt ON' : 'Tilt OFF',
              onPressed: () => bt.tiltEnabled
                  ? bt.disableTilt()
                  : bt.enableTilt(),
            ),
        ],
      ),
    );
  }
}
