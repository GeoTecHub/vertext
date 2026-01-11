import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class Mountpoint {
  final String name;
  final String format; // e.g., RTCM 3.x
  final String nmea;   // "N" or "Y"
  final String navSys; // GPS/GLO/GAL/...
  Mountpoint(this.name, this.format, this.nmea, this.navSys);
}

class NtripViewModel extends ChangeNotifier {
  Socket? _socket;
  bool connecting = false;
  bool streaming = false;
  String? error;
  int bytesIn = 0;

  final _chunks = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rtcmStream => _chunks.stream;

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

    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
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
            mp.add(Mountpoint(parts[1], parts[3], parts[6], parts[7]));
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
  }) async {
    try {
      connecting = true; error = null; notifyListeners();
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));

      final auth = base64Encode(utf8.encode('$user:$password'));
      final req = 'GET /$mountPoint HTTP/1.1\r\n'
          'Host: $host\r\n'
          'Ntrip-Version: Ntrip/2.0\r\n'
          'User-Agent: VerTextFlutter/1.0\r\n'
          'Authorization: Basic $auth\r\n\r\n';

      _socket!.add(utf8.encode(req));
      await _socket!.flush();

      _socket!.listen((data) {
        // Some casters prepend HTTP header; trim until the first 0xD3
        final d3 = data.indexOf(0xD3);
        if (d3 > 0) {
          final sliced = data.sublist(d3);
          bytesIn += sliced.length;
          _chunks.add(Uint8List.fromList(sliced));
        } else {
          bytesIn += data.length;
          _chunks.add(Uint8List.fromList(data));
        }
        notifyListeners();
      }, onDone: () {
        streaming = false; notifyListeners();
      }, onError: (e) {
        error = e.toString(); streaming = false; notifyListeners();
      });

      if (nmeaGGA != null && nmeaGGA.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        _socket!.add(utf8.encode('$nmeaGGA\r\n'));
      }

      streaming = true; connecting = false; notifyListeners();
    } catch (e) {
      error = e.toString(); connecting = false; streaming = false; notifyListeners();
      try { _socket?.destroy(); } catch (_) {}
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
    try { _socket?.destroy(); } catch (_) {}
    _socket = null;
    streaming = false;
    connecting = false;
    error = null;
    notifyListeners();
  }
}
