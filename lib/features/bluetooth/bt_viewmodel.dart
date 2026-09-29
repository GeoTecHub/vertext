import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models/gnss_device_profile.dart';

class SdFileEntry {
  final String name;
  final double sizeKb;
  const SdFileEntry(this.name, this.sizeKb);
}

class BtViewModel extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final BtViewModel _instance = BtViewModel._internal();
  factory BtViewModel() => _instance;
  static BtViewModel get instance => _instance;
  BtViewModel._internal();

  final _bt = FlutterBluetoothSerial.instance;
  BluetoothConnection? _conn;
  Socket? _wifiSocket;

  bool get isWifi => _wifiSocket != null;

  bool connecting = false;
  bool connected  = false;
  String? error;
  bool _intentionalDisconnect = false;

  String? _lastBtAddress;
  String? _lastWifiHost;
  int?    _lastWifiPort;
  bool    _isReconnecting = false;

  // ── Live receive stats ───────────────────────────────────────────────────────
  int       lineCount = 0;
  DateTime? lastRxAt;
  String?   lastLine;

  final List<String> logs = <String>[];
  static const int _maxLogs = 200;

  // ── Parsed GNSS fields ───────────────────────────────────────────────────────
  LatLng? currentPos;
  double? currentAlt;
  double? currentHdop;
  double? currentPdop;
  double? currentVdop;
  double? currentHrms;
  double? currentVrms;
  double? currentSpeed;
  double? currentHeading;
  String? currentBaseId;
  double? currentDiffAge;
  String? currentSolution;

  // ── Tilt sensor ──────────────────────────────────────────────────────────────
  double? currentRoll;
  double? currentPitch;
  bool    tiltEnabled = false;

  double get totalTilt => (currentRoll != null && currentPitch != null)
      ? totalTiltDeg(currentRoll!, currentPitch!)
      : 0.0;

  // ── Device profile & HI ─────────────────────────────────────────────────────
  GnssDeviceProfile selectedDevice = kVertextV2;
  double poleHeight = 2.000;   // metres (user-entered)
  double rodHeight  = 0.000;   // additional rod/tribrach height (for tripod setups)

  double get correctedHI {
    final hi = poleHeight + rodHeight;
    if (!tiltEnabled || currentRoll == null || currentPitch == null) return hi;
    return tiltCorrectedHI(hi, currentRoll!, currentPitch!);
  }

  double? get correctedEllipsoidHeight {
    if (currentAlt == null) return null;
    return correctedEllipsoidalHeight(
      gnssAlt: currentAlt!,
      correctedHI: correctedHI,
      phaseCentreOffset: selectedDevice.phaseCentreOffset,
    );
  }

  // ── SD card state ────────────────────────────────────────────────────────────
  double sdTotalMb = 0;
  double sdFreeMb  = 0;
  int    sdFileCount = 0;
  List<SdFileEntry> sdFiles = [];
  bool   sdListLoading = false;

  // ── Static session state ─────────────────────────────────────────────────────
  bool   isStaticRecording    = false;
  String staticSessionName    = '';
  DateTime? staticSessionStart;
  int    staticBytesRecorded  = 0;
  String staticLastFilename   = '';

  // ── File download state ──────────────────────────────────────────────────────
  bool   isDownloadingFile  = false;
  String downloadFilename   = '';
  int    downloadExpectedBytes = 0;
  final StringBuffer _downloadBuf = StringBuffer();
  void Function(String filename, String content)? onFileDownloadComplete;

  // ── Track recording ──────────────────────────────────────────────────────────
  bool _recording = false;
  final List<LatLng> _track = [];
  bool get recording => _recording;
  List<LatLng> get track => List.unmodifiable(_track);
  int get trackPoints => _track.length;

  void Function(String line)? onLine;

  bool get receiving =>
      lastRxAt != null && DateTime.now().difference(lastRxAt!).inSeconds <= 3;

  // ── TX pipeline ──────────────────────────────────────────────────────────────
  final StreamController<Uint8List> _txQueue =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _txWorker;
  int bytesTx = 0;

  void _startTxWorkerIfNeeded() {
    if (_txWorker != null) return;
    _txWorker = _txQueue.stream.listen((payload) async {
      if (!connected || (_conn == null && _wifiSocket == null)) return;
      const chunkSize = 256;
      for (int i = 0; i < payload.length; i += chunkSize) {
        final end = (i + chunkSize < payload.length) ? i + chunkSize : payload.length;
        final chunk = payload.sublist(i, end);
        if (_wifiSocket != null) {
          _wifiSocket!.add(chunk);
        } else {
          final out = _conn?.output;
          if (out != null) { out.add(chunk); await out.allSent; }
        }
        bytesTx += chunk.length;
        await Future.delayed(const Duration(milliseconds: 15));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  // ── RTCM forwarding ──────────────────────────────────────────────────────────
  StreamSubscription<Uint8List>? _rtcmForwardSub;
  bool get isForwardingRtcm => _rtcmForwardSub != null;

  void bindRtcmStream(Stream<Uint8List> stream) {
    _rtcmForwardSub?.cancel();
    _rtcmForwardSub = stream.listen((chunk) => sendRtcm(chunk), onError: (_) {});
    notifyListeners();
  }

  void unbindRtcmStream() {
    _rtcmForwardSub?.cancel();
    _rtcmForwardSub = null;
    notifyListeners();
  }

  // ── BT bonded devices ────────────────────────────────────────────────────────
  Future<List<BluetoothDevice>> bondedDevices() =>
      _bt.getBondedDevices();

  // ── Discovery ────────────────────────────────────────────────────────────────
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  bool isDiscovering = false;
  List<BluetoothDiscoveryResult> results = [];

  void startDiscovery() {
    if (isDiscovering) return;
    _discoveryStreamSubscription?.cancel();
    isDiscovering = true;
    results.clear();
    notifyListeners();
    _discoveryStreamSubscription = _bt.startDiscovery().listen((r) {
      final idx = results.indexWhere((e) => e.device.address == r.device.address);
      if (idx >= 0) results[idx] = r; else results.add(r);
      notifyListeners();
    })..onDone(() { isDiscovering = false; notifyListeners(); });
  }

  void cancelDiscovery() {
    _discoveryStreamSubscription?.cancel();
    isDiscovering = false;
    notifyListeners();
  }

  Future<bool> bondDevice(String address) async {
    try { return await _bt.bondDeviceAtAddress(address) ?? false; }
    catch (e) { error = "Bonding failed: $e"; notifyListeners(); return false; }
  }

  // ── Connect (BT) ─────────────────────────────────────────────────────────────
  Future<void> connect(String address) async {
    try {
      if (!_isReconnecting) {
        _intentionalDisconnect = false;
        _lastBtAddress = address;
        _lastWifiHost  = null;
      }
      error = null; connecting = true; notifyListeners();
      _conn = await BluetoothConnection.toAddress(address);
      connected = true; connecting = false;
      await WakelockPlus.enable();
      notifyListeners();
      _startTxWorkerIfNeeded();
      _listenToStream();

      // Ask device for SD info and enable tilt if supported
      if (selectedDevice.hasSdCard)     _sendText('CMD:SD_INFO\n');
      if (selectedDevice.hasTiltSensor) _sendText('CMD:TILT_ON\n');
    } catch (e) {
      error = e.toString(); connecting = false; connected = false;
      notifyListeners();
    }
  }

  void _listenToStream() {
    String carry = '';
    _conn!.input?.listen((data) {
      final s = carry + String.fromCharCodes(data);
      final parts = s.split(RegExp(r'\r?\n'));
      carry = parts.isNotEmpty ? parts.removeLast() : '';
      for (final ln in parts) {
        final line = ln.trim();
        if (line.isEmpty) continue;
        _handleLine(line);
      }
    }, onDone: () {
      WakelockPlus.disable();
      if (!_intentionalDisconnect) _handleUnexpectedDisconnect();
      else { connected = false; notifyListeners(); }
    }, onError: (e) {
      error = e.toString(); WakelockPlus.disable();
      if (!_intentionalDisconnect) _handleUnexpectedDisconnect();
      else { connected = false; notifyListeners(); }
    });
  }

  void _handleLine(String line) {
    lastLine = line; lastRxAt = DateTime.now(); lineCount++;
    logs.add(line);
    if (logs.length > _maxLogs) logs.removeRange(0, logs.length - _maxLogs);

    // Device-protocol lines (intercept before forwarding to GNSS parser)
    if (_tryParseDeviceProtocol(line)) { notifyListeners(); return; }

    _tryParseForQuickFields(line);
    onLine?.call(line);
    notifyListeners();
  }

  // ── Device command protocol parser ───────────────────────────────────────────
  bool _tryParseDeviceProtocol(String line) {
    // SDINFO:{totalMb},{freeMb},{fileCount}
    if (line.startsWith('SDINFO:')) {
      final parts = line.substring(7).split(',');
      if (parts.length >= 2) {
        sdTotalMb   = double.tryParse(parts[0]) ?? 0;
        sdFreeMb    = double.tryParse(parts[1]) ?? 0;
        sdFileCount = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
      }
      return true;
    }

    // SDFILE:{name},{sizeKb}
    if (line.startsWith('SDFILE:')) {
      final parts = line.substring(7).split(',');
      if (parts.isNotEmpty) {
        final name  = parts[0].trim();
        final sizeKb = parts.length >= 2 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0;
        sdFiles.removeWhere((e) => e.name == name);
        sdFiles.add(SdFileEntry(name, sizeKb));
      }
      return true;
    }

    // SDLIST_END
    if (line == 'SDLIST_END') {
      sdListLoading = false;
      return true;
    }

    // SDGET_START:{name},{size}
    if (line.startsWith('SDGET_START:')) {
      final rest = line.substring(12);
      final comma = rest.lastIndexOf(',');
      downloadFilename     = comma > 0 ? rest.substring(0, comma) : rest;
      downloadExpectedBytes = comma > 0 ? (int.tryParse(rest.substring(comma + 1)) ?? 0) : 0;
      isDownloadingFile    = true;
      _downloadBuf.clear();
      return true;
    }

    // SDGET_END:{name}
    if (line.startsWith('SDGET_END:')) {
      isDownloadingFile = false;
      final content = _downloadBuf.toString();
      _downloadBuf.clear();
      final fname = downloadFilename;
      onFileDownloadComplete?.call(fname, content);
      _saveDownloadedFile(fname, content);
      return true;
    }

    // SDGET_ERR:{reason}
    if (line.startsWith('SDGET_ERR:')) {
      isDownloadingFile = false;
      error = line.substring(10);
      return true;
    }

    // Lines between SDGET_START and SDGET_END are file content
    if (isDownloadingFile) {
      _downloadBuf.write(line);
      _downloadBuf.write('\n');
      return true;
    }

    // STATIC_OK:{filename}
    if (line.startsWith('STATIC_OK:')) {
      isStaticRecording  = true;
      staticSessionStart = DateTime.now();
      staticLastFilename = line.substring(10);
      return true;
    }

    // STATIC_DONE:{filename},{bytes}
    if (line.startsWith('STATIC_DONE:')) {
      final rest  = line.substring(12);
      final comma = rest.lastIndexOf(',');
      staticLastFilename    = comma > 0 ? rest.substring(0, comma) : rest;
      staticBytesRecorded   = comma > 0 ? (int.tryParse(rest.substring(comma + 1)) ?? 0) : 0;
      isStaticRecording     = false;
      staticSessionStart    = null;
      // Refresh SD info after session completes
      requestSdInfo();
      return true;
    }

    // STATIC_ERR:{reason}
    if (line.startsWith('STATIC_ERR:')) {
      error = 'Static error: ${line.substring(11)}';
      isStaticRecording = false;
      return true;
    }

    // TILT:{roll},{pitch}
    if (line.startsWith('TILT:')) {
      final parts = line.substring(5).split(',');
      if (parts.length >= 2) {
        currentRoll  = double.tryParse(parts[0]);
        currentPitch = double.tryParse(parts[1]);
      }
      return true;
    }

    // TILT_OK:{ON|OFF}
    if (line.startsWith('TILT_OK:')) {
      tiltEnabled = line.contains('ON');
      return true;
    }

    // STATUS:{...}
    if (line.startsWith('STATUS:')) return true;

    return false;
  }

  // ── Device profile setter (notifies listeners) ───────────────────────────────
  void setDevice(GnssDeviceProfile profile) {
    selectedDevice = profile;
    notifyListeners();
  }

  /// Call after changing poleHeight / rodHeight from UI to rebuild dependents.
  void notifyHiChanged() => notifyListeners();

  // ── SD commands ──────────────────────────────────────────────────────────────
  void requestSdInfo()  => _sendText('CMD:SD_INFO\n');

  void requestSdList() {
    sdFiles.clear();
    sdListLoading = true;
    notifyListeners();
    _sendText('CMD:SD_LIST\n');
  }

  void downloadFile(String filename,
      {void Function(String filename, String content)? onComplete}) {
    onFileDownloadComplete = onComplete;
    isDownloadingFile = false;
    _downloadBuf.clear();
    _sendText('CMD:SD_GET,$filename\n');
  }

  void enableTilt() {
    tiltEnabled = true;
    _sendText('CMD:TILT_ON\n');
    notifyListeners();
  }

  void disableTilt() {
    tiltEnabled = false;
    _sendText('CMD:TILT_OFF\n');
    notifyListeners();
  }

  // ── Static session commands ──────────────────────────────────────────────────
  void startStaticSession(String sessionName) {
    staticSessionName = sessionName;
    _sendText('CMD:STATIC_START,$sessionName\n');
  }

  void stopStaticSession() => _sendText('CMD:STATIC_STOP\n');

  // ── Send raw text command ────────────────────────────────────────────────────
  void _sendText(String cmd) {
    if (!connected) return;
    _startTxWorkerIfNeeded();
    _txQueue.add(Uint8List.fromList(cmd.codeUnits));
  }

  // ── Save downloaded file to device storage ───────────────────────────────────
  Future<void> _saveDownloadedFile(String filename, String content) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);
    } catch (_) {}
  }

  // ── WiFi ─────────────────────────────────────────────────────────────────────
  // ignore: deprecated_member_use
  List<WifiNetwork> wifiResults = [];
  bool isWifiScanning = false;

  Future<void> startWifiScan() async {
    if (isWifiScanning) return;
    isWifiScanning = true; wifiResults.clear(); notifyListeners();
    try {
      // ignore: deprecated_member_use
      wifiResults = await WiFiForIoTPlugin.loadWifiList();
    } catch (e) { error = "WiFi Scan: $e"; }
    finally { isWifiScanning = false; notifyListeners(); }
  }

  Future<void> connectToWifiAp(String ssid, {String? password}) async {
    try {
      error = null; notifyListeners();
      final ok = await WiFiForIoTPlugin.connect(ssid,
          password: password, security: NetworkSecurity.WPA);
      if (!ok && !kDebugMode) {
        error = "Failed to connect to $ssid"; notifyListeners(); return;
      }
      if (ok) { await Future.delayed(const Duration(seconds: 2)); await connectWifi("192.168.4.1", 2101); }
    } catch (e) { error = "WiFi AP: $e"; notifyListeners(); }
  }

  Future<void> connectWifi(String host, int port) async {
    disconnect();
    _intentionalDisconnect = false;
    _lastWifiHost = host; _lastWifiPort = port; _lastBtAddress = null;
    try {
      error = null; connecting = true; notifyListeners();
      _wifiSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      connected = true; connecting = false;
      await WakelockPlus.enable();
      notifyListeners();
      _startTxWorkerIfNeeded();

      String carry = '';
      _wifiSocket!.listen((data) {
        final s = carry + String.fromCharCodes(data);
        final parts = s.split(RegExp(r'\r?\n'));
        carry = parts.isNotEmpty ? parts.removeLast() : '';
        for (final ln in parts) {
          final line = ln.trim();
          if (line.isEmpty) continue;
          _handleLine(line);
        }
      }, onDone: () {
        if (!_intentionalDisconnect) _handleUnexpectedDisconnect(); else disconnect();
      }, onError: (e) {
        error = e.toString();
        if (!_intentionalDisconnect) _handleUnexpectedDisconnect(); else disconnect();
      });

      // Request SD info on connect
      if (selectedDevice.hasSdCard)     _sendText('CMD:SD_INFO\n');
      if (selectedDevice.hasTiltSensor) _sendText('CMD:TILT_ON\n');
    } catch (e) {
      error = "WiFi: $e"; connecting = false; connected = false; notifyListeners();
    }
  }

  void sendRtcm(List<int> bytes) {
    if (!connected || (_conn == null && _wifiSocket == null)) return;
    _startTxWorkerIfNeeded();
    _txQueue.add(Uint8List.fromList(bytes));
  }

  void _handleUnexpectedDisconnect() {
    connected = false; notifyListeners();
    if (!_isReconnecting) _attemptReconnect();
  }

  Future<void> _attemptReconnect() async {
    _isReconnecting = true;
    error = "Connection lost. Reconnecting..."; notifyListeners();
    await Future.delayed(const Duration(seconds: 3));
    if (_intentionalDisconnect) { _isReconnecting = false; return; }
    try {
      if (_lastBtAddress != null) await connect(_lastBtAddress!);
      else if (_lastWifiHost != null) await connectWifi(_lastWifiHost!, _lastWifiPort!);
    } catch (_) {
      if (!_intentionalDisconnect) {
        error = "Reconnection failed. Retrying..."; notifyListeners();
        await Future.delayed(const Duration(seconds: 5));
        _attemptReconnect(); return;
      }
    }
    _isReconnecting = false;
  }

  void disconnect() {
    _intentionalDisconnect = true; _isReconnecting = false;
    if (tiltEnabled) { tiltEnabled = false; }
    try { _txWorker?.cancel(); _txWorker = null; } catch (_) {}
    try { _conn?.dispose(); } catch (_) {}
    _conn = null;
    try { _wifiSocket?.destroy(); } catch (_) {}
    _wifiSocket = null;
    connected = false;
    WakelockPlus.disable();
    notifyListeners();
  }

  void clearLogs() { logs.clear(); notifyListeners(); }

  // ── Track recording ──────────────────────────────────────────────────────────
  void startRecording()  { _track.clear(); _recording = true; notifyListeners(); }
  void stopRecording()   { _recording = false; notifyListeners(); }
  void clearTrack()      { _track.clear(); notifyListeners(); }

  Map<String, dynamic> toGeoJsonLineString({Map<String, dynamic>? properties}) => {
    'type': 'Feature',
    'properties': properties ?? {},
    'geometry': {
      'type': 'LineString',
      'coordinates': _track.map((e) => [e.longitude, e.latitude]).toList(),
    },
  };

  void _maybeAppendToTrack(LatLng p) {
    if (!_recording) return;
    if (_track.isEmpty || _track.last.latitude != p.latitude ||
        _track.last.longitude != p.longitude) {
      _track.add(p);
    }
  }

  // ── GNSS NMEA / JSON parser ──────────────────────────────────────────────────
  void _tryParseForQuickFields(String line) {
    if (line.isEmpty) return;

    if (line.startsWith('{') && line.endsWith('}')) {
      final lat = _jNum(line, 'latitude')  ?? _jNum(line, 'lat');
      final lon = _jNum(line, 'longitude') ?? _jNum(line, 'lon') ?? _jNum(line, 'lng');
      if (lat != null && lon != null) { currentPos = LatLng(lat, lon); _maybeAppendToTrack(currentPos!); }
      currentAlt     = _jNum(line, 'altitude')  ?? _jNum(line, 'alt')   ?? currentAlt;
      currentHdop    = _jNum(line, 'hdop')       ?? _jNum(line, 'HDOP')  ?? currentHdop;
      currentPdop    = _jNum(line, 'pdop')       ?? _jNum(line, 'PDOP')  ?? currentPdop;
      currentVdop    = _jNum(line, 'vdop')       ?? _jNum(line, 'VDOP')  ?? currentVdop;
      final fix = _jStr(line, 'fix_type') ?? _jStr(line, 'solution') ?? _jStr(line, 'fix');
      if (fix != null && fix.isNotEmpty) currentSolution = fix;
      return;
    }

    if (line.startsWith('\$GPGGA') || line.startsWith('\$GNGGA')) {
      final f = line.split(',');
      if (f.length > 9) {
        if (f[2].isNotEmpty && f[4].isNotEmpty) {
          final lat = _nmeaToDeg(f[2], f[3]);
          final lon = _nmeaToDeg(f[4], f[5]);
          if (lat != null && lon != null) { currentPos = LatLng(lat, lon); _maybeAppendToTrack(currentPos!); }
        }
        if (f[6].isNotEmpty) currentSolution = _fixQualityText(f[6]);
        if (f[8].isNotEmpty) currentHdop = double.tryParse(f[8]) ?? currentHdop;
        if (f[9].isNotEmpty) currentAlt  = double.tryParse(f[9]) ?? currentAlt;
        if (f.length > 13 && f[13].isNotEmpty) currentDiffAge = double.tryParse(f[13]) ?? currentDiffAge;
        if (f.length > 14 && f[14].isNotEmpty) currentBaseId  = f[14].split('*')[0];
      }
      return;
    }

    if (line.startsWith('\$GPGST') || line.startsWith('\$GNGST')) {
      final f = line.split(',');
      if (f.length > 8) {
        final latStd = double.tryParse(f[6]) ?? 0.0;
        final lonStd = double.tryParse(f[7]) ?? 0.0;
        final altStd = double.tryParse(f[8].split('*')[0]) ?? 0.0;
        currentVrms = altStd;
        currentHrms = (latStd + lonStd) / 2.0;
      }
      return;
    }

    if (line.startsWith('\$GPVTG') || line.startsWith('\$GNVTG')) {
      final f = line.split(',');
      if (f.length > 8) {
        if (f[1].isNotEmpty) currentHeading = double.tryParse(f[1]) ?? currentHeading;
        if (f[7].isNotEmpty) currentSpeed   = double.tryParse(f[7]) ?? currentSpeed;
      }
      return;
    }

    if (line.startsWith('\$GPGSA') || line.startsWith('\$GNGSA')) {
      final f = line.split(',');
      if (f.length > 17) {
        if (f[15].isNotEmpty) currentPdop = double.tryParse(f[15]) ?? currentPdop;
        if (f[16].isNotEmpty) currentHdop = double.tryParse(f[16]) ?? currentHdop;
        final vd = f[17].split('*')[0];
        if (vd.isNotEmpty) currentVdop = double.tryParse(vd) ?? currentVdop;
      }
      return;
    }

    // Stonex / Trimble tilt proprietary sentences
    if (line.startsWith('\$PTNL,AVr')) {
      final f = line.split(',');
      if (f.length > 4) { currentPitch = double.tryParse(f[4]) ?? currentPitch; }
      return;
    }
    if (line.startsWith('\$PSTI,030')) {
      final f = line.split(',');
      if (f.length > 5) {
        currentRoll  = double.tryParse(f[4]) ?? currentRoll;
        currentPitch = double.tryParse(f[5]) ?? currentPitch;
      }
      return;
    }
  }

  double? _jNum(String json, String key) {
    final i = json.indexOf('"$key"'); if (i < 0) return null;
    final c = json.indexOf(':', i);  if (c < 0) return null;
    final e = json.indexOf(RegExp(r'[,\}]'), c + 1);
    return double.tryParse(json.substring(c + 1, e > 0 ? e : json.length).trim().replaceAll('"', ''));
  }

  String? _jStr(String json, String key) {
    final i = json.indexOf('"$key"'); if (i < 0) return null;
    final c = json.indexOf(':', i);  if (c < 0) return null;
    final e = json.indexOf(RegExp(r'[,\}]'), c + 1);
    var s = json.substring(c + 1, e > 0 ? e : json.length).trim();
    if (s.startsWith('"')) s = s.substring(1);
    if (s.endsWith('"'))   s = s.substring(0, s.length - 1);
    return s;
  }

  double? _nmeaToDeg(String dm, String hemi) {
    if (dm.isEmpty) return null;
    final deg = (hemi == 'N' || hemi == 'S') ? 2 : 3;
    if (dm.length <= deg) return null;
    final d = double.tryParse(dm.substring(0, deg));
    final m = double.tryParse(dm.substring(deg));
    if (d == null || m == null) return null;
    double v = d + m / 60.0;
    if (hemi == 'S' || hemi == 'W') v = -v;
    return v.abs() > 180 ? null : v;
  }

  String _fixQualityText(String q) => switch (int.tryParse(q)) {
    0 => 'INVALID', 1 => 'SINGLE', 2 => 'DGNSS',
    4 => 'FIXED',   5 => 'FLOAT',  6 => 'DR', _ => 'UNKNOWN',
  };
}
