import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bluetooth/bt_viewmodel.dart';
import '../sdcard/sdcard_view.dart';

class StaticObservationView extends StatefulWidget {
  const StaticObservationView({super.key});
  @override
  State<StaticObservationView> createState() => _StaticObservationViewState();
}

class _StaticObservationViewState extends State<StaticObservationView> {
  final _nameCtrl     = TextEditingController();
  final _hiCtrl       = TextEditingController(text: '2.000');
  Duration _elapsed   = Duration.zero;
  bool _timerRunning  = false;
  DateTime? _startTime;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hiCtrl.dispose();
    super.dispose();
  }

  void _startSession(BtViewModel bt) {
    if (!bt.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to device')),
      );
      return;
    }
    if (!bt.selectedDevice.hasStaticMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            '${bt.selectedDevice.displayName} does not support static mode')),
      );
      return;
    }
    final hi = double.tryParse(_hiCtrl.text) ?? 2.0;
    bt.poleHeight = hi;

    final sessionName = _nameCtrl.text.trim().isEmpty
        ? _autoSessionName()
        : _nameCtrl.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

    bt.startStaticSession(sessionName);
    _startTime    = DateTime.now();
    _timerRunning = true;
    _tick();
  }

  void _stopSession(BtViewModel bt) {
    bt.stopStaticSession();
    _timerRunning = false;
    _startTime    = null;
  }

  void _tick() async {
    while (_timerRunning && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_startTime != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(_startTime!));
      }
    }
  }

  String _autoSessionName() {
    final now = DateTime.now();
    return 'VTX'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BtViewModel>();
    final recording = bt.isStaticRecording;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Static GNSS Observation'),
        backgroundColor: const Color(0xFF222222),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sd_card_outlined),
            tooltip: 'SD Card Browser',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SdCardView())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status card ────────────────────────────────────────────────
            _StatusCard(bt: bt, elapsed: _elapsed, recording: recording),
            const SizedBox(height: 16),

            // ── Session configuration ──────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Session Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      enabled: !recording,
                      decoration: const InputDecoration(
                        labelText: 'Session Name (optional)',
                        hintText: 'Auto-generated if blank',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hiCtrl,
                      enabled: !recording,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Antenna Height / HI (m)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                        suffixText: 'm',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Device: ${bt.selectedDevice.displayName}  •  '
                      'Phase centre offset: '
                      '${bt.selectedDevice.phaseCentreOffset.toStringAsFixed(4)} m',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── GNSS quality indicators ────────────────────────────────────
            _GnssQualityRow(bt: bt),
            const SizedBox(height: 12),

            // ── Start / Stop ───────────────────────────────────────────────
            if (!recording)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
                label: const Text('Start Static Observation',
                    style: TextStyle(fontSize: 16)),
                onPressed: bt.connected ? () => _startSession(bt) : null,
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('Stop & Save to SD Card',
                    style: TextStyle(fontSize: 16)),
                onPressed: () => _stopSession(bt),
              ),

            const SizedBox(height: 16),

            // ── Last session info ──────────────────────────────────────────
            if (bt.staticLastFilename.isNotEmpty) ...[
              Card(
                color: Colors.green[50],
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Last session: ${bt.staticLastFilename}'),
                  subtitle: Text(
                      '${(bt.staticBytesRecorded / 1024).toStringAsFixed(1)} KB saved'),
                  trailing: IconButton(
                    icon: const Icon(Icons.sd_card_outlined),
                    tooltip: 'Open SD Card browser',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SdCardView())),
                  ),
                ),
              ),
            ],

            // ── Instructions ───────────────────────────────────────────────
            const SizedBox(height: 8),
            _InstructionCard(),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.bt, required this.elapsed, required this.recording});
  final BtViewModel bt;
  final Duration elapsed;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: recording ? Colors.red[700] : const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            recording ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording ? 'RECORDING' : 'STANDBY',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                if (recording) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Duration: ${_fmt(elapsed)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (bt.staticLastFilename.isNotEmpty)
                    Text(bt.staticLastFilename,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (bt.connected)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bt.currentSolution ?? '—',
                  style: TextStyle(
                      color: _solColor(bt.currentSolution),
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  bt.currentPos != null
                      ? '${bt.currentPos!.latitude.toStringAsFixed(6)}\n'
                        '${bt.currentPos!.longitude.toStringAsFixed(6)}'
                      : 'No position',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _solColor(String? sol) {
    switch (sol?.toUpperCase()) {
      case 'FIXED':  return Colors.greenAccent;
      case 'FLOAT':  return Colors.yellowAccent;
      case 'DGNSS':  return Colors.lightBlueAccent;
      default:       return Colors.white70;
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _GnssQualityRow extends StatelessWidget {
  const _GnssQualityRow({required this.bt});
  final BtViewModel bt;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _q('HDOP', bt.currentHdop?.toStringAsFixed(2)),
            _q('PDOP', bt.currentPdop?.toStringAsFixed(2)),
            _q('HRMS', bt.currentHrms != null
                ? '${(bt.currentHrms! * 1000).toStringAsFixed(0)} mm' : null),
            _q('VRMS', bt.currentVrms != null
                ? '${(bt.currentVrms! * 1000).toStringAsFixed(0)} mm' : null),
          ],
        ),
      ),
    );
  }

  Widget _q(String label, String? value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value ?? '—',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _InstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Static Observation Guidelines',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Set antenna height (bottom of receiver to ground mark).'),
            Text('• Ensure RTK Fixed solution before starting.'),
            Text('• Minimum observation: 20 min for short baselines.'),
            Text('• Keep receiver stationary throughout session.'),
            Text('• After stopping, download file from SD Card browser.'),
            Text('• Files are saved in raw NMEA format (.nmea).'),
          ],
        ),
      ),
    );
  }
}
