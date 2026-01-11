import 'dart:async';
// NOTE: Uint8List is re-exported by foundation; no need for dart:typed_data
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:latlong2/latlong.dart';

class BtViewModel extends ChangeNotifier {
  // ---------- Singleton wiring ----------
  static final BtViewModel _instance = BtViewModel._internal();
  factory BtViewModel() => _instance;
  static BtViewModel get instance => _instance;
  BtViewModel._internal();
  // --------------------------------------

  final _bt = FlutterBluetoothSerial.instance;
  BluetoothConnection? _conn;

  bool connecting = false;
  bool connected = false;
  String? error;

  /// Live receive stats
  int lineCount = 0;
  DateTime? lastRxAt;
  String? lastLine;

  /// Ring buffer of recent lines (for on-screen console)
  final List<String> logs = <String>[];
  static const int _maxLogs = 200;

  /// Parsed quick fields (for verification on BT page)
  LatLng? currentPos;
  double? currentAlt;
  double? currentHdop;
  String? currentSolution; // Invalid/GPS/DGPS/RTK-Fixed/RTK-Float/…

  /// Track recording
  bool _recording = false;
  final List<LatLng> _track = [];
  bool get recording => _recording;
  List<LatLng> get track => List.unmodifiable(_track);
  int get trackPoints => _track.length;

  /// Optional: forward each decoded line to an external parser (e.g., GnssLiveViewModel)
  void Function(String line)? onLine;

  /// Convenience: "receiving" if a line arrived in the last 3s
  bool get receiving =>
      lastRxAt != null && DateTime.now().difference(lastRxAt!).inSeconds <= 3;

  // ----------------- Robust TX pipeline (keeps your API) -----------------
  final StreamController<Uint8List> _txQueue =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _txWorker;

  /// TX counter (so your UI can show bytes out)
  int bytesTx = 0;

  void _startTxWorkerIfNeeded() {
    if (_txWorker != null) return;
    _txWorker = _txQueue.stream.listen((payload) async {
      if (!connected || _conn == null) return;
      const int chunkSize = 256;
      for (int i = 0; i < payload.length; i += chunkSize) {
        final end = (i + chunkSize < payload.length) ? i + chunkSize : payload.length;
        final chunk = payload.sublist(i, end);
        final out = _conn?.output;
        if (out == null) break;
        out.add(chunk);
        await out.allSent;             // back-pressure
        bytesTx += chunk.length;
        await Future.delayed(const Duration(milliseconds: 1)); // yield
      }
      notifyListeners();
    }, onError: (_) {});
  }
  // -----------------------------------------------------------------------

  // ----------------- NEW: persistent RTCM forward binding -----------------
  StreamSubscription<Uint8List>? _rtcmForwardSub;

  /// Bind a RTCM byte stream to Bluetooth sending (persists across screens).
  /// Safe to call multiple times; it will replace the previous binding.
  void bindRtcmStream(Stream<Uint8List> stream) {
    _rtcmForwardSub?.cancel();
    _rtcmForwardSub = stream.listen((chunk) {
      sendRtcm(chunk); // goes through the queued/chunked TX pipeline
    }, onError: (_) {});
  }

  /// Optional: unbind the RTCM stream (e.g., when you intentionally stop NTRIP).
  void unbindRtcmStream() {
    _rtcmForwardSub?.cancel();
    _rtcmForwardSub = null;
  }
  // -----------------------------------------------------------------------

  Future<List<BluetoothDevice>> bondedDevices() async {
    return await _bt.getBondedDevices();
  }

  Future<void> connect(String address) async {
    try {
      error = null;
      connecting = true;
      notifyListeners();

      _conn = await BluetoothConnection.toAddress(address);
      connected = true;
      connecting = false;
      notifyListeners();

      _startTxWorkerIfNeeded();

      String carry = '';
      _conn!.input?.listen((data) {
        final s = carry + String.fromCharCodes(data);
        final parts = s.split(RegExp(r'\r?\n'));
        carry = parts.isNotEmpty ? parts.removeLast() : '';
        for (final ln in parts) {
          final line = ln.trim();
          if (line.isEmpty) continue;

          // Stats
          lastLine = line;
          lastRxAt = DateTime.now();
          lineCount += 1;

          // Ring buffer
          logs.add(line);
          if (logs.length > _maxLogs) {
            logs.removeRange(0, logs.length - _maxLogs);
          }

          // Quick parse (JSON preferred; fallback NMEA GGA)
          _tryParseForQuickFields(line);

          // Forward outward if app wired an external parser
          onLine?.call(line);

          notifyListeners();
        }
      }, onDone: () {
        connected = false;
        notifyListeners();
      }, onError: (e) {
        error = e.toString();
        connected = false;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString();
      connecting = false;
      connected = false;
      notifyListeners();
    }
  }

  /// Send RTCM bytes to the GNSS receiver (bridge to the stream)
  void sendRtcm(List<int> bytes) {
    if (!connected || _conn == null) return;
    _startTxWorkerIfNeeded();
    _txQueue.add(Uint8List.fromList(bytes));
  }

  void disconnect() {
    try {
      _txWorker?.cancel();
      _txWorker = null;
    } catch (_) {}
    try {
      _rtcmForwardSub?.cancel();
      _rtcmForwardSub = null;
    } catch (_) {}
    try {
      _conn?.dispose();
    } catch (_) {}
    _conn = null;
    connected = false;
    notifyListeners();
  }

  /// Clear the console safely from UI
  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  // ----- Track recording API -----
  void startRecording() {
    _track.clear();
    _recording = true;
    notifyListeners();
  }

  void stopRecording() {
    _recording = false;
    notifyListeners();
  }

  void clearTrack() {
    _track.clear();
    notifyListeners();
  }

  Map<String, dynamic> toGeoJsonLineString({Map<String, dynamic>? properties}) {
    return {
      'type': 'Feature',
      'properties': properties ?? {},
      'geometry': {
        'type': 'LineString',
        'coordinates': _track.map((e) => [e.longitude, e.latitude]).toList(),
      },
    };
  }

  void _maybeAppendToTrack(LatLng p) {
    if (!_recording) return;
    if (_track.isEmpty ||
        _track.last.latitude != p.latitude ||
        _track.last.longitude != p.longitude) {
      _track.add(p);
      // notifyListeners(); // optional; UI already updates frequently
    }
  }

  // ---- minimal inline parsing for verification panel ----
  void _tryParseForQuickFields(String line) {
    if (line.isEmpty) return;

    // JSON first: {"latitude":..,"longitude":..,"altitude":..,"hdop":..,"fix_type":..}
    if (line.startsWith('{') && line.endsWith('}')) {
      final lat = _extractJsonNumber(line, 'latitude') ?? _extractJsonNumber(line, 'lat');
      final lon = _extractJsonNumber(line, 'longitude') ??
          _extractJsonNumber(line, 'lon') ??
          _extractJsonNumber(line, 'lng');
      if (lat != null && lon != null) {
        currentPos = LatLng(lat, lon);
        _maybeAppendToTrack(currentPos!); // record if enabled
      }
      currentAlt = _extractJsonNumber(line, 'altitude') ??
          _extractJsonNumber(line, 'alt') ??
          currentAlt;
      currentHdop = _extractJsonNumber(line, 'hdop') ??
          _extractJsonNumber(line, 'HDOP') ??
          currentHdop;

      final fixType = _extractJsonString(line, 'fix_type') ??
          _extractJsonString(line, 'solution') ??
          _extractJsonString(line, 'fix');
      if (fixType != null && fixType.isNotEmpty) currentSolution = fixType;
      return;
    }

    // NMEA GGA
    if (line.startsWith('\$GPGGA') || line.startsWith('\$GNGGA')) {
      final f = line.split(',');
      if (f.length > 9) {
        final lat = _nmeaToDeg(f[2], f[3]);
        final lon = _nmeaToDeg(f[4], f[5]);
        if (lat != null && lon != null) {
          currentPos = LatLng(lat, lon);
          _maybeAppendToTrack(currentPos!);
        }
        currentSolution = _fixQualityToText(f[6]); // 0..6
        currentHdop = double.tryParse(f[8]) ?? currentHdop;
        currentAlt = double.tryParse(f[9]) ?? currentAlt;
      }
      return;
    }
  }

  // tolerant JSON extractors
  double? _extractJsonNumber(String json, String key) {
    final i = json.indexOf('"$key"');
    if (i < 0) return null;
    final colon = json.indexOf(':', i);
    if (colon < 0) return null;
    final end = json.indexOf(RegExp(r'[,\}]'), colon + 1);
    final slice = json.substring(colon + 1, end > 0 ? end : json.length).trim();
    final cleaned = slice.replaceAll('"', '');
    return double.tryParse(cleaned);
  }

  String? _extractJsonString(String json, String key) {
    final i = json.indexOf('"$key"');
    if (i < 0) return null;
    final colon = json.indexOf(':', i);
    if (colon < 0) return null;
    final end = json.indexOf(RegExp(r'[,\}]'), colon + 1);
    var slice = json.substring(colon + 1, end > 0 ? end : json.length).trim();
    if (slice.startsWith('"')) slice = slice.substring(1);
    if (slice.endsWith('"')) slice = slice.substring(0, slice.length - 1);
    return slice;
  }

  double? _nmeaToDeg(String dm, String hemi) {
    if (dm.isEmpty) return null;
    final degDigits = (hemi == 'N' || hemi == 'S') ? 2 : 3;
    if (dm.length <= degDigits) return null;
    final deg = double.tryParse(dm.substring(0, degDigits));
    final min = double.tryParse(dm.substring(degDigits));
    if (deg == null || min == null) return null;
    double d = deg + (min / 60.0);
    if (hemi == 'S' || hemi == 'W') d = -d;
    if (d.abs() > 180) return null;
    return d;
  }

  String _fixQualityToText(String q) {
    final n = int.tryParse(q);
    return switch (n) {
      0 => 'Invalid',
      1 => 'GPS',
      2 => 'DGPS',
      4 => 'RTK-Fixed',
      5 => 'RTK-Float',
      6 => 'DR',
      _ => 'Unknown',
    };
  }
}
