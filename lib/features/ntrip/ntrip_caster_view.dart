import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ntrip_viewmodel.dart';
import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';

// ---------------- Local preset model ----------------
class _NtripPreset {
  final String name;
  final String host;
  final int port;
  final String user;
  final String password;

  _NtripPreset({
    required this.name,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'host': host, 'port': port, 'user': user, 'password': password,
  };

  factory _NtripPreset.fromJson(Map<String, dynamic> j) => _NtripPreset(
    name: j['name'] ?? '',
    host: j['host'] ?? '',
    port: (j['port'] is int) ? j['port'] : int.tryParse('${j['port']}') ?? 2101,
    user: j['user'] ?? '',
    password: j['password'] ?? '',
  );
}

const _kNtripPresetsKey = 'ntrip_presets_v1';

class NtripCasterView extends StatefulWidget {
  const NtripCasterView({super.key});
  @override
  State<NtripCasterView> createState() => _NtripCasterViewState();
}

class _NtripCasterViewState extends State<NtripCasterView> {
  final host = TextEditingController();
  final port = TextEditingController(text: '2101');
  final user = TextEditingController();
  final pass = TextEditingController();

  // Presets
  final presetName = TextEditingController();
  List<_NtripPreset> presets = [];
  String? selectedPresetName;

  // Mountpoints
  List<Mountpoint> mps = [];
  String? selectedMp;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    user.dispose();
    pass.dispose();
    presetName.dispose();
    super.dispose();
  }

  // ---------------- Presets ----------------
  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNtripPresetsKey);
    final list = <_NtripPreset>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final arr = jsonDecode(raw) as List<dynamic>;
        for (final e in arr) {
          list.add(_NtripPreset.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    setState(() {
      presets = list;
      selectedPresetName ??= (presets.isNotEmpty ? presets.first.name : null);
      if (selectedPresetName != null) {
        final p = presets.firstWhere((e) => e.name == selectedPresetName);
        _applyPreset(p);
      }
    });
  }

  Future<void> _savePresets(List<_NtripPreset> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kNtripPresetsKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  void _applyPreset(_NtripPreset p) {
    host.text = p.host;
    port.text = p.port.toString();
    user.text = p.user;
    pass.text = p.password;
  }

  Future<void> _savePreset() async {
    final name = presetName.text.trim().isEmpty
        ? '${host.text.trim()}:${port.text.trim()}'
        : presetName.text.trim();

    final p = _NtripPreset(
      name: name,
      host: host.text.trim(),
      port: int.tryParse(port.text.trim()) ?? 2101,
      user: user.text.trim(),
      password: pass.text.trim(),
    );

    final list = [...presets];
    final i = list.indexWhere((e) => e.name.toLowerCase() == p.name.toLowerCase());
    if (i >= 0) { list[i] = p; } else { list.add(p); }
    await _savePresets(list);
    setState(() {
      presets = list;
      selectedPresetName = p.name;
    });
    presetName.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preset saved')));
    }
  }

  Future<void> _deleteSelectedPreset() async {
    final name = selectedPresetName;
    if (name == null) return;
    final list = [...presets]..removeWhere((e) => e.name.toLowerCase() == name.toLowerCase());
    await _savePresets(list);
    setState(() {
      presets = list;
      selectedPresetName = presets.isNotEmpty ? presets.first.name : null;
    });
  }

  // ---------------- Mountpoint + Connect ----------------
  Future<void> _fetchMountpoints() async {
    setState(() => loading = true);
    try {
      final list = await context.read<NtripViewModel>().fetchMountpoints(
        host: host.text.trim(),
        port: int.tryParse(port.text.trim()) ?? 2101,
        user: user.text.trim(),
        password: pass.text.trim(),
      );
      setState(() {
        mps = list;
        selectedMp = list.isNotEmpty ? list.first.name : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch failed: $e')));
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _connect() async {
    final ntrip = context.read<NtripViewModel>();
    final bt = context.read<BtViewModel>();

    // Ensure persistent binding BEFORE streaming starts
    bt.bindRtcmStream(ntrip.rtcmStream);

    if (selectedMp == null) {
      await _fetchMountpoints();
      if (selectedMp == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No mountpoints available')));
        }
        return;
      }
    }

    await ntrip.connect(
      host: host.text.trim(),
      port: int.tryParse(port.text.trim()) ?? 2101,
      mountPoint: selectedMp!,
      user: user.text.trim(),
      password: pass.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ntrip = context.watch<NtripViewModel>();
    final bt = context.watch<BtViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('NTRIP Caster')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Preset selector row
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPresetName,
                    hint: const Text('Select preset'),
                    items: presets.map((e) =>
                      DropdownMenuItem(value: e.name, child: Text(e.name))).toList(),
                    onChanged: (v) {
                      setState(() => selectedPresetName = v);
                      final p = presets.firstWhere((e) => e.name == v);
                      _applyPreset(p);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete preset',
                  onPressed: selectedPresetName == null ? null : _deleteSelectedPreset,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),

            const Text('Caster'),
            TextField(controller: host, decoration: const InputDecoration(labelText: 'Host')),
            Row(children: [
              Expanded(child: TextField(
                controller: port, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port (2101)'),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: user,
                decoration: const InputDecoration(labelText: 'Username'),
              )),
            ]),
            TextField(
              controller: pass, obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: presetName,
                    decoration: const InputDecoration(labelText: 'Preset name (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _savePreset,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save preset'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(children: [
              FilledButton.icon(
                icon: const Icon(Icons.list),
                onPressed: loading ? null : _fetchMountpoints,
                label: const Text('Fetch Mountpoints'),
              ),
              const SizedBox(width: 12),
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),

            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Mountpoint'),
              child: DropdownButton<String>(
                value: selectedMp,
                isExpanded: true,
                hint: const Text('Select a mountpoint'),
                items: mps.map((e) => DropdownMenuItem(
                  value: e.name,
                  child: Text('${e.name} • ${e.format} • ${e.navSys}'),
                )).toList(),
                onChanged: (v) => setState(() => selectedMp = v),
              ),
            ),

            const SizedBox(height: 16),
            Row(children: [
              FilledButton(
                onPressed: (ntrip.streaming || ntrip.connecting) ? null : _connect,
                child: const Text('Connect'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: ntrip.streaming ? () {
                  ntrip.disconnect();
                  // optional: bt.unbindRtcmStream(); // if you want to stop forwarding when disconnected
                } : null,
                child: const Text('Disconnect'),
              ),
            ]),

            const SizedBox(height: 8),
            Text('NTRIP: ${ntrip.connecting ? "Connecting..." : (ntrip.streaming ? "Streaming" : "Idle")} • In ${ntrip.bytesIn} B'),
            Text('BT: ${bt.connected ? "Connected" : (bt.connecting ? "Connecting..." : "Disconnected")} • Out ${bt.bytesTx} B'),
            if (ntrip.error != null) Text(ntrip.error!, style: const TextStyle(color: Colors.red)),
            if (bt.error != null) Text(bt.error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
