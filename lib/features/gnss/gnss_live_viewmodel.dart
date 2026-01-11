import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/live_bus.dart';

class GnssLiveViewModel extends ChangeNotifier {
  LatLng? position;
  double? altitude; // meters
  double? hdop;
  double? pdop;
  double? vdop;
  String? solution; // e.g., Invalid/GPS/DGPS/RTK-Fixed/RTK-Float/Autonomous
  int? satsInUse;
  DateTime? lastUpdate;
  String? lastLine;

  final _posStream = StreamController<LatLng>.broadcast();
  Stream<LatLng> get stream => _posStream.stream;

  void updateFromLine(String line) {
    lastLine = line;
    LiveBus.lastLine.value = line; // publish for HUD

    // 1) JSON status (preferred if your firmware sends it)
    if (line.trim().startsWith('{')) {
      try {
        final j = jsonDecode(line);
        final lat = (j['latitude'] as num?)?.toDouble();
        final lon = (j['longitude'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          final pos = LatLng(lat, lon);
          _setPos(pos);
          altitude = (j['altitude'] as num?)?.toDouble() ?? altitude;
          hdop    = (j['hdop']    as num?)?.toDouble() ?? hdop;
          pdop    = (j['pdop']    as num?)?.toDouble() ?? pdop;
          vdop    = (j['vdop']    as num?)?.toDouble() ?? vdop;
          satsInUse = (j['satellites_in_use'] as num?)?.toInt()
                   ?? (j['satellites']        as num?)?.toInt()
                   ?? satsInUse;
          final fx = (j['fix_type'] ?? j['solution'])?.toString();
          if (fx != null && fx.isNotEmpty) solution = fx;
          lastUpdate = DateTime.now();
          notifyListeners();
          return;
        }
      } catch (_) {
        // fall through to NMEA parsing
      }
    }

    // 2) NMEA GGA: position, altitude, HDOP, fix quality
    if (line.startsWith('\$GPGGA') || line.startsWith('\$GNGGA')) {
      final f = line.split(',');
      if (f.length > 9) {
        final lat = _nmeaToDeg(f[2], f[3]);
        final lon = _nmeaToDeg(f[4], f[5]);
        if (lat != null && lon != null) {
          _setPos(LatLng(lat, lon));
        }
        // f[6] fix quality: 0=Invalid,1=GPS,2=DGPS,4=RTK Fixed,5=RTK Float,6=Dead reckoning
        solution = _fixQualityToText(f[6]);
        hdop = double.tryParse(f[8]) ?? hdop;
        altitude = double.tryParse(f[9]) ?? altitude;
        lastUpdate = DateTime.now();
        notifyListeners();
        return;
      }
    }

    // 3) NMEA GSA: PDOP/HDOP/VDOP + fix mode (M/A) & type (1/2/3D)
    if (line.startsWith('\$GPGSA') || line.startsWith('\$GNGSA')) {
      final f = line.split(',');
      // f[2]: Fix type (1=no fix, 2=2D, 3=3D)
      if (f.length >= 18) {
        final fixType = int.tryParse(f[2]);// 1/2/3
        if (fixType != null) {
          solution = switch (fixType) {
            1 => 'No Fix',
            2 => '2D',
            3 => '3D',
            _ => solution ?? 'Unknown'
          };
        }
        pdop = double.tryParse(f[15]) ?? pdop;
        hdop = double.tryParse(f[16]) ?? hdop;
        // f[17] may have *checksum*, trim it
        final vd = f[17].split('*').first;
        vdop = double.tryParse(vd) ?? vdop;
        lastUpdate = DateTime.now();
        notifyListeners();
      }
    }
  }

  // --- helpers ---

  void _setPos(LatLng pos) {
    position = pos;
    lastUpdate = DateTime.now();
    _posStream.add(pos);
    LiveBus.pos.value = pos; // publish to global bus so map always sees it
  }

  String? _fixQualityToText(String q) {
    final n = int.tryParse(q);
    return switch (n) {
      0 => 'Invalid',
      1 => 'GPS',
      2 => 'DGPS',
      4 => 'RTK-Fixed',
      5 => 'RTK-Float',
      6 => 'DR',
      _ => solution ?? 'Unknown'
    };
  }

  /// Converts NMEA ddmm.mmmm (lat, N/S) or dddmm.mmmm (lon, E/W) to degrees.
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
}
