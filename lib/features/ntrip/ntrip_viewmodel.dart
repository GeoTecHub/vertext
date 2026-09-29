import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/live_bus.dart';

class Mountpoint {
  final String name;
  final String format; // e.g., RTCM 3.x
  final String nmea; // "N" or "Y"
  final String navSys; // GPS/GLO/GAL/...
  final double? latitude;
  final double? longitude;

  Mountpoint(this.name, this.format, this.nmea, this.navSys,
      {this.latitude, this.longitude});
}

class NtripViewModel extends ChangeNotifier {
  Socket? _socket;
  bool connecting = false;
  bool streaming = false;
  String? error;
  int bytesIn = 0;
  String? activeMountpoint;

  // Base Station Position (from mountpoint info)
  LatLng? basePosition;

  // True once the HTTP 200 header has been consumed and the RTCM stream begins.
  // Reset on every connect() call so a fresh connection always re-strips.
  bool _headerStripped = false;

  // Reconnection state — cleared by disconnect() so user-initiated stops
  // never trigger an automatic retry.
  Map<String, dynamic>? _lastConnectArgs;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Rolling byte buffer used to reassemble RTCM frames that arrive across
  // multiple TCP chunks.  Capped at [_maxRtcmBuf] bytes; older bytes are
  // evicted from the front when the cap is exceeded.
  final List<int> _rtcmBuf = [];
  static const int _maxRtcmBuf = 2048;

  final _chunks = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rtcmStream => _chunks.stream;

  NtripViewModel() {
    LiveBus.lastLine.addListener(_onNewGnssLine);
  }

  @override
  void dispose() {
    LiveBus.lastLine.removeListener(_onNewGnssLine);
    _reconnectTimer?.cancel();
    _chunks.close();
    super.dispose();
  }

  void _onNewGnssLine() {
    if (!streaming || _socket == null) return;
    final line = LiveBus.lastLine.value;
    if (line == null || line.isEmpty) return;

    // VRS Casters require our current position via GGA
    if (line.startsWith('\$GPGGA') || line.startsWith('\$GNGGA')) {
      try {
        _socket!.add(utf8.encode('${line.trim()}\r\n'));
      } catch (_) {
        // Ignored. Socket might be closed and it will error out in the main listener.
      }
    }
  }

  // -------------------- PUBLIC API (unchanged) --------------------

  Future<List<Mountpoint>> fetchMountpoints({
    required String host,
    required int port,
    required String user,
    required String password,
  }) async {
    final auth = base64Encode(utf8.encode('$user:$password'));
    final req = 'GET / HTTP/1.1\r\n'
        'Host: $host\r\n'
        'Ntrip-Version: Ntrip/2.0\r\n'
        'User-Agent: VerTextFlutter/1.0\r\n'
        'Authorization: Basic $auth\r\n\r\n';

    final socket =
        await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    socket.add(utf8.encode(req));
    await socket.flush();

    final mp = <Mountpoint>[];
    final buf = StringBuffer();
    final c = Completer<List<Mountpoint>>();

    socket.listen((data) {
      buf.write(utf8.decode(data, allowMalformed: true));
    }, onDone: () {
      for (final raw in buf.toString().split(RegExp(r'\r?\n'))) {
        if (raw.startsWith('STR;')) {
          final parts = raw.split(';');
          if (parts.length > 7) {
            // STR;MOUNTPOINT;ID;FORMAT;FORMAT-DETAILS;CARR;NAV-SYS;NETWORK;COUNTRY;LAT;LON;NMEA;SOLUTION;GENERATOR;COMP;AUTH;FEE;BITRATE
            // 0   1          2  3      4              5    6       7       8       9   10  11   ...
            double? lat, lon;
            if (parts.length > 10) lat = double.tryParse(parts[9]);
            if (parts.length > 11) lon = double.tryParse(parts[10]);

            mp.add(Mountpoint(
                parts[1],  // name
                parts[3],  // format
                parts.length > 11 ? parts[11] : 'N',  // nmea Y/N flag
                parts[6],  // nav-system
                latitude: lat, longitude: lon));
          }
        }
      }
      if (!c.isCompleted) c.complete(mp);
    }, onError: (e) {
      if (!c.isCompleted) c.completeError(e);
    });

    return c.future.timeout(const Duration(seconds: 12), onTimeout: () => mp);
  }

  Future<void> connect({
    required String host,
    required int port,
    required String mountPoint,
    required String user,
    required String password,
    String? nmeaGGA, // optional initial GGA
    LatLng? stationPos,
  }) async {
    try {
      _headerStripped = false;       // re-strip header on every (re)connect
      _reconnectTimer?.cancel();     // cancel any in-flight retry timer
      _rtcmBuf.clear();              // discard stale frame fragments
      connecting = true;
      error = null;
      basePosition = stationPos;
      activeMountpoint = mountPoint;
      notifyListeners();
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));

      // Save params so _scheduleReconnect() can reopen the same stream.
      _lastConnectArgs = {
        'host': host,
        'port': port,
        'mountPoint': mountPoint,
        'user': user,
        'password': password,
      };

      final auth = base64Encode(utf8.encode('$user:$password'));

      final req = 'GET /$mountPoint HTTP/1.1\r\n'
          'Host: $host\r\n'
          'Ntrip-Version: Ntrip/2.0\r\n'
          'User-Agent: VerTextFlutter/1.0\r\n'
          'Authorization: Basic $auth\r\n\r\n';

      _socket!.add(utf8.encode(req));
      await _socket!.flush();

      _socket!.listen((data) {
        Uint8List payload;

        if (!_headerStripped) {
          // The very first bytes from the caster are the HTTP 200 OK response
          // header (ASCII text).  RTCM frames start with the sync byte 0xD3.
          // Scan the chunk for 0xD3; everything before it is header and must
          // be discarded.  If 0xD3 is not in this chunk at all, the chunk is
          // still pure HTTP header — discard it and wait for the next one.
          final d3 = data.indexOf(0xD3);
          if (d3 < 0) return; // entire chunk is HTTP header — discard
          _headerStripped = true;
          payload = Uint8List.fromList(data.sublist(d3));
        } else {
          // Header already consumed — every subsequent chunk is raw RTCM.
          payload = Uint8List.fromList(data);
        }

        bytesIn += payload.length;
        _chunks.add(payload);          // forward to ZED-F9P via BtViewModel
        _processRtcmChunk(payload);    // parse base coordinates if present
        notifyListeners();
      }, onDone: () {
        _socket = null;
        streaming = false;
        notifyListeners();
        _scheduleReconnect(); // attempt to reopen the stream automatically
      }, onError: (e) {
        _socket = null;
        error = e.toString();
        streaming = false;
        notifyListeners();
        _scheduleReconnect();
      });

      if (nmeaGGA != null && nmeaGGA.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        _socket!.add(utf8.encode('$nmeaGGA\r\n'));
      }

      streaming = true;
      connecting = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      connecting = false;
      streaming = false;
      notifyListeners();
      try {
        _socket?.destroy();
      } catch (_) {}
      _socket = null;
    }
  }

  /// Optional: send GGA later (if caster requires keep-alive positions)
  void sendGGA(String nmeaGGA) {
    if (_socket != null) {
      _socket!.add(utf8.encode('$nmeaGGA\r\n'));
    }
  }

  void disconnect() {
    // Cancel any pending reconnect BEFORE destroying the socket so that the
    // onDone callback (which fires when we destroy) cannot re-schedule a retry.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _lastConnectArgs = null;  // sentinel: no reconnect wanted
    _reconnectAttempts = 0;
    _rtcmBuf.clear();
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    streaming = false;
    connecting = false;
    error = null;
    activeMountpoint = null;
    notifyListeners();
  }

  // ── RTCM 1005 / 1006 base station coordinate extraction ─────────────────
  //
  // RTCM message type 1005 (Stationary RTK Reference Station ARP) and 1006
  // (same + antenna height) embed the base station coordinates as ECEF XYZ.
  // These are the authoritative coordinates — more precise than the ~1°
  // rounded values in the NTRIP source table, and present even when the
  // source table omits coordinates entirely.
  //
  // RTCM frame layout:
  //   [0xD3] [2-byte length, 10 bits] [payload, length bytes] [3-byte CRC24]
  //
  // 1005 payload bit layout (19 bytes / 152 bits):
  //   Bits  0–11:   Message Type (1005 or 1006)
  //   Bits 12–23:   Reference Station ID
  //   Bits 24–33:   Flags (ITRF, GPS/GLONASS/Galileo indicators)
  //   Bits 34–71:   ECEF X  (38-bit signed, unit = 0.0001 m)
  //   Bits 72–73:   Oscillator / reserved
  //   Bits 74–111:  ECEF Y  (38-bit signed, unit = 0.0001 m)
  //   Bits 112–113: Quarter-cycle indicator
  //   Bits 114–151: ECEF Z  (38-bit signed, unit = 0.0001 m)
  //   1006 appends a 16-bit antenna height field which we ignore.

  /// Append [chunk] to the rolling buffer and scan for complete 1005/1006 frames.
  void _processRtcmChunk(Uint8List chunk) {
    _rtcmBuf.addAll(chunk);
    // Evict from the front if the buffer grows beyond the cap.
    if (_rtcmBuf.length > _maxRtcmBuf) {
      _rtcmBuf.removeRange(0, _rtcmBuf.length - _maxRtcmBuf);
    }
    _scanForRtcm1005();
  }

  /// Walk [_rtcmBuf] looking for complete RTCM 1005/1006 frames.
  void _scanForRtcm1005() {
    int i = 0;
    while (i <= _rtcmBuf.length - 6) {
      // Every RTCM frame starts with the sync byte 0xD3.
      if (_rtcmBuf[i] != 0xD3) {
        i++;
        continue;
      }

      // Length is a 10-bit big-endian value in bytes i+1..i+2.
      final length = ((_rtcmBuf[i + 1] & 0x03) << 8) | _rtcmBuf[i + 2];
      final frameEnd = i + 3 + length + 3; // sync(3) + payload + CRC(3)

      if (frameEnd > _rtcmBuf.length) break; // partial frame — wait for more

      // Message type is the first 12 bits of the payload (MSB first).
      final msgType = (_rtcmBuf[i + 3] << 4) | (_rtcmBuf[i + 4] >> 4);

      if ((msgType == 1005 && length == 19) ||
          (msgType == 1006 && length == 21)) {
        final payload =
            Uint8List.fromList(_rtcmBuf.sublist(i + 3, i + 3 + length));
        final pos = _parseRtcm1005(payload);
        if (pos != null) {
          // Update only when the position changes (base stations are fixed,
          // so after the first good fix this branch rarely fires again).
          final prev = basePosition;
          if (prev == null ||
              (pos.latitude - prev.latitude).abs() > 1e-7 ||
              (pos.longitude - prev.longitude).abs() > 1e-7) {
            basePosition = pos;
            notifyListeners();
          }
        }
      }

      i = frameEnd; // advance past this frame
    }
    // Discard bytes that have been fully processed.
    if (i > 0) _rtcmBuf.removeRange(0, i.clamp(0, _rtcmBuf.length));
  }

  /// Parse a 1005/1006 payload and return the base station [LatLng], or null
  /// if the payload is malformed or the ECEF vector is outside Earth's surface.
  LatLng? _parseRtcm1005(Uint8List p) {
    if (p.length < 19) return null;

    // Extract the three 38-bit signed ECEF fields (unit = 0.0001 m → metres).
    final x = _extractSigned(p, 34, 38) * 0.0001;
    final y = _extractSigned(p, 74, 38) * 0.0001;
    final z = _extractSigned(p, 114, 38) * 0.0001;

    // Sanity: ECEF magnitude must be close to Earth's surface (6 200–6 450 km).
    final r = math.sqrt(x * x + y * y + z * z);
    if (r < 6200000 || r > 6450000) return null;

    return _ecefToLatLng(x, y, z);
  }

  /// Extract [numBits] bits starting at [bitOffset] (big-endian / MSB-first).
  int _extractBits(Uint8List data, int bitOffset, int numBits) {
    int result = 0;
    for (int i = 0; i < numBits; i++) {
      final byteIdx = (bitOffset + i) ~/ 8;
      final bitPos = 7 - ((bitOffset + i) % 8); // MSB of each byte = bit 7
      if (byteIdx < data.length) {
        result = (result << 1) | ((data[byteIdx] >> bitPos) & 1);
      }
    }
    return result;
  }

  /// Same as [_extractBits] but sign-extends the result to a Dart [int].
  int _extractSigned(Uint8List data, int bitOffset, int numBits) {
    final raw = _extractBits(data, bitOffset, numBits);
    // If the MSB of the field is 1, the value is negative in 2's complement.
    if (numBits > 0 && ((raw >> (numBits - 1)) & 1) == 1) {
      return raw - (1 << numBits);
    }
    return raw;
  }

  /// Convert ECEF (metres) to WGS-84 geodetic degrees using Bowring's method.
  LatLng? _ecefToLatLng(double x, double y, double z) {
    const double a = 6378137.0;             // semi-major axis (m)
    const double f = 1.0 / 298.257223563;   // WGS-84 flattening
    const double b = a * (1.0 - f);         // semi-minor axis
    const double e2 = 2.0 * f - f * f;      // first eccentricity²
    const double ep2 = (a * a - b * b) / (b * b); // second eccentricity²

    final p = math.sqrt(x * x + y * y);
    if (p < 1.0) return null; // degenerate (at polar axis)

    // One iteration of Bowring's parametric formula — sufficient for cm accuracy.
    final theta = math.atan2(z * a, p * b);
    final lat = math.atan2(
      z + ep2 * b * math.pow(math.sin(theta), 3),
      p - e2 * a * math.pow(math.cos(theta), 3),
    );
    final lon = math.atan2(y, x);

    const double toDeg = 180.0 / math.pi;
    final latDeg = lat * toDeg;
    final lonDeg = lon * toDeg;

    if (latDeg < -90.0 || latDeg > 90.0 ||
        lonDeg < -180.0 || lonDeg > 180.0) {
      return null;
    }

    return LatLng(latDeg, lonDeg);
  }

  /// Automatically called when the TCP socket closes or errors unexpectedly.
  /// Retries the same connection up to [_maxReconnectAttempts] times with a
  /// linearly increasing delay (3 s, 6 s, 9 s …).
  void _scheduleReconnect() {
    if (_lastConnectArgs == null) return; // user called disconnect() — stop
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      error = 'NTRIP: lost connection after $_maxReconnectAttempts attempts. '
          'Tap "Start Download" to retry.';
      notifyListeners();
      return;
    }
    _reconnectAttempts++;
    final delaySec = _reconnectAttempts * 3; // 3 s, 6 s, 9 s …
    error = 'NTRIP disconnected. Reconnecting in ${delaySec}s '
        '(attempt $_reconnectAttempts/$_maxReconnectAttempts)…';
    notifyListeners();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () async {
      if (_lastConnectArgs == null) return; // disconnect() fired while waiting
      final args = _lastConnectArgs!;
      await connect(
        host: args['host'] as String,
        port: args['port'] as int,
        mountPoint: args['mountPoint'] as String,
        user: args['user'] as String,
        password: args['password'] as String,
      );
    });
  }
}
