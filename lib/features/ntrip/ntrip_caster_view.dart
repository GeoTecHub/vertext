import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

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
        'name': name,
        'host': host,
        'port': port,
        'user': user,
        'password': password,
      };

  factory _NtripPreset.fromJson(Map<String, dynamic> j) => _NtripPreset(
        name: j['name'] ?? '',
        host: j['host'] ?? '',
        port: (j['port'] is int)
            ? j['port']
            : int.tryParse('${j['port']}') ?? 2101,
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
  List<_NtripPreset> presets = [];
  String? selectedPresetName;

  // Mountpoints
  List<Mountpoint> mps = [];
  String? selectedMp;
  bool loading = false;

  // Logic state
  // We no longer use local _forwarding, it's read dynamically from BtViewModel

  // Logs
  final List<String> _logs = [];
  bool _logsExpanded = false;
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPresets();
    _log("Ready.");
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() {
      final time =
          DateTime.now().toIso8601String().split('T').last.split('.').first;
      _logs.add("[$time] $msg");
      // Auto-scroll if at bottom?
    });
    // Scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    user.dispose();
    pass.dispose();
    _logScrollCtrl.dispose();
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
    _log("Applied preset: ${p.name}");
  }

  Future<void> _showSavePresetDialog() async {
    final nameCtrl =
        TextEditingController(text: '${host.text.trim()}:${port.text.trim()}');
    final pName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Name your Preset"),
              content: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: "Preset Name"),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                    child: const Text("Save")),
              ],
            ));

    if (pName == null || pName.trim().isEmpty) return;

    _log("Saving preset: $pName...");

    final p = _NtripPreset(
      name: pName.trim(),
      host: host.text.trim(),
      port: int.tryParse(port.text.trim()) ?? 2101,
      user: user.text.trim(),
      password: pass.text.trim(),
    );

    final list = [...presets];
    final i =
        list.indexWhere((e) => e.name.toLowerCase() == p.name.toLowerCase());
    if (i >= 0) {
      list[i] = p;
    } else {
      list.add(p);
    }
    await _savePresets(list);
    setState(() {
      presets = list;
      selectedPresetName = p.name;
    });
    _log("Preset saved.");
  }

  Future<void> _deletePreset(String name) async {
    final list = presets.where((e) => e.name != name).toList();
    await _savePresets(list);
    setState(() {
      presets = list;
      if (selectedPresetName == name) {
        selectedPresetName = list.isNotEmpty ? list.first.name : null;
        if (selectedPresetName != null) {
          _applyPreset(list.firstWhere((e) => e.name == selectedPresetName));
        } else {
          host.clear();
          user.clear();
          pass.clear();
        }
      }
    });
    _log("Preset '$name' deleted.");
  }

  // ---------------- Mountpoint + Connect ----------------
  Future<void> _fetchMountpoints() async {
    setState(() => loading = true);
    _log("Fetching mountpoints from ${host.text}...");
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
      _log("Fetched ${list.length} mountpoints.");
    } catch (e) {
      _log("Fetch failed: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _startNtrip() async {
    final ntrip = context.read<NtripViewModel>();

    // Auto-save manually entered entries on connect
    if (host.text.isNotEmpty && port.text.isNotEmpty && presets.isEmpty) {
      _showSavePresetDialog();
    }

    if (selectedMp == null) {
      _log("No mountpoint selected. Fetching...");
      await _fetchMountpoints();
      if (selectedMp == null) {
        _log("Error: No mountpoints found.");
        return;
      }
    }

    // Find position
    LatLng? stationPos;
    try {
      final mpObj = mps.firstWhere((e) => e.name == selectedMp);
      if (mpObj.latitude != null && mpObj.longitude != null) {
        stationPos = LatLng(mpObj.latitude!, mpObj.longitude!);
      }
    } catch (_) {}

    _log("Connecting to $selectedMp...");
    await ntrip.connect(
      host: host.text.trim(),
      port: int.tryParse(port.text.trim()) ?? 2101,
      mountPoint: selectedMp!,
      user: user.text.trim(),
      password: pass.text.trim(),
      stationPos: stationPos,
    );

    if (ntrip.streaming && mounted) {
      final bt = context.read<BtViewModel>();
      bt.bindRtcmStream(ntrip.rtcmStream);
      _log("NTRIP Connected. RTCM corrections forwarding to rover.");
    } else {
      _log("NTRIP Connected. Waiting for stream...");
    }
  }

  Future<void> _stopNtrip() async {
    _log("Stopping NTRIP...");
    final ntrip = context.read<NtripViewModel>();
    ntrip.disconnect();
    final bt = context.read<BtViewModel>();
    bt.unbindRtcmStream();
    _log("NTRIP Stopped.");
  }

  Future<void> _applyForwarding() async {
    final ntrip = context.read<NtripViewModel>();
    final bt = context.read<BtViewModel>();

    if (!ntrip.streaming) {
      _log("Error: Start NTRIP first before Applying.");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please START NTRIP first.")));
      return;
    }

    if (!bt.connected) {
      _log("Warning: No Rover connected yet. "
          "Corrections are queued and will forward automatically once the device connects.");
    }

    _log("Applying corrections to Rover...");
    // Bind RTCM
    bt.bindRtcmStream(ntrip.rtcmStream);
    _log("Forwarding ENABLED.");
  }

  // --- UI WIDGETS ---

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          if (trailing != null) trailing
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
          border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey)),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ntrip = context.watch<NtripViewModel>();
    final bt = context.watch<BtViewModel>();

    bool isStreaming = ntrip.streaming;
    bool isForwarding = bt.isForwardingRtcm;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Rover Mode Settings',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF222222),
        leading: const BackButton(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Datalink Settings
                  _buildSectionHeader("Datalink Settings"),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Connecting Mode: NTRIP",
                            style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                  // Inputs
                  if (presets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Saved Presets",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              DropdownButton<String>(
                                value: selectedPresetName,
                                hint: const Text("Select >"),
                                underline: Container(),
                                items: presets
                                    .map((e) => DropdownMenuItem(
                                        value: e.name, child: Text(e.name)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => selectedPresetName = v);
                                    final p =
                                        presets.firstWhere((e) => e.name == v);
                                    _applyPreset(p);
                                  }
                                },
                              ),
                              if (selectedPresetName != null)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () =>
                                      _deletePreset(selectedPresetName!),
                                )
                            ],
                          )
                        ],
                      ),
                    ),
                  _buildTextField("IP", host),
                  _buildTextField("Server Port", port),
                  _buildTextField("User", user),
                  _buildTextField("Password", pass, obscure: true),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _showSavePresetDialog,
                      icon: const Icon(Icons.save),
                      label: const Text("Save Preset"),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Mountpoint Settings
                  _buildSectionHeader("Mountpoint Settings",
                      trailing: SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          onPressed: loading ? null : _fetchMountpoints,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Get",
                                  style: TextStyle(color: Colors.black)),
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Mountpoint"),
                        DropdownButton<String>(
                          value: selectedMp,
                          hint: const Text("Select >"),
                          underline: Container(),
                          items: mps
                              .map((e) => DropdownMenuItem(
                                  value: e.name, child: Text(e.name)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedMp = v),
                        ),
                      ],
                    ),
                  ),

                  const Divider(thickness: 1, height: 30),

                  // 3. Main Controls (Start / Apply)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Start Button (Toggle)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isStreaming ? _stopNtrip : _startNtrip,
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isStreaming ? Colors.red : Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            child: Text(
                                isStreaming
                                    ? "Stop Download"
                                    : "Start Download",
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Apply Button (Enable Forwarding)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isStreaming ? _applyForwarding : null,
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF1E3A8A), // Navy Blue
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            child: const Text("Apply (Send)",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  if (isForwarding && isStreaming)
                    Column(
                      children: [
                        const Text("✅ Forwarding Corrections to Rover",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(
                            "Mountpoint: ${ntrip.activeMountpoint ?? 'Unknown'}",
                            style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.black12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                  // 4. Logs Header
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => setState(() => _logsExpanded = !_logsExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: Colors.grey[200],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Log Screen",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Icon(_logsExpanded
                              ? Icons.expand_less
                              : Icons.expand_more),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Log Area (Collapsible)
          if (_logsExpanded)
            Container(
              height: 200,
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: _logScrollCtrl,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(_logs[index],
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontFamily: "Monospace"));
                },
              ),
            ),
        ],
      ),
    );
  }
}
