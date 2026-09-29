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
  int? satsInView;
  DateTime? lastUpdate;
  String? lastLine;

  final _posStream = StreamController<LatLng>.broadcast();
  Stream<LatLng> get stream => _posStream.stream;

  void updateFromLine(String line) {
    lastLine = line;
    LiveBus.lastLine.value = line; // publish for HUD

    // 1) JSON status (ESP32 Custom Status)
    if (line.trim().startsWith('{')) {
      try {
        final j = jsonDecode(line);
        final lat = (j['latitude'] as num?)?.toDouble() ??
            (j['lat'] as num?)?.toDouble();
        final lon = (j['longitude'] as num?)?.toDouble() ??
            (j['lon'] as num?)?.toDouble();

        if (lat != null && lon != null) {
          final pos = LatLng(lat, lon);
          _setPos(pos);
          altitude = (j['altitude'] as num?)?.toDouble() ??
              (j['alt'] as num?)?.toDouble() ??
              altitude;
          hdop = (j['hdop'] as num?)?.toDouble() ?? hdop;
          pdop = (j['pdop'] as num?)?.toDouble() ?? pdop;
          vdop = (j['vdop'] as num?)?.toDouble() ?? vdop;
          satsInUse = (j['satellites_in_use'] as num?)?.toInt() ??
              (j['satellites'] as num?)?.toInt() ??
              (j['sats'] as num?)?.toInt() ??
              satsInUse;
          satsInView = (j['satellites_in_view'] as num?)?.toInt() ?? satsInView;

          final fx = (j['fix_type'] ?? j['solution'] ?? j['fix'])?.toString();
          if (fx != null && fx.isNotEmpty) {
            // Standardize names a bit for HomeInfoBar colors
            if (fx == "RTK Fixed") {
              solution = "FIXED";
            } else if (fx == "RTK Float")
              solution = "FLOAT";
            else if (fx == "3D Fix" || fx == "DGNSS" || fx == "DGNSS/3D")
              solution = "DGNSS";
            else
              solution = fx.toUpperCase();
          }

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
        // Only parse if we have actual lat/lon data
        if (f[2].isNotEmpty && f[4].isNotEmpty) {
          final lat = _nmeaToDeg(f[2], f[3]);
          final lon = _nmeaToDeg(f[4], f[5]);
          if (lat != null && lon != null) {
            _setPos(LatLng(lat, lon));
          }
        }

        // f[6] fix quality
        if (f[6].isNotEmpty) {
          solution = _fixQualityToText(f[6]);
        }

        // f[7] satellites in use
        if (f[7].isNotEmpty) {
          satsInUse = int.tryParse(f[7]) ?? satsInUse;
        }

        // f[8] hdop
        if (f[8].isNotEmpty) {
          hdop = double.tryParse(f[8]) ?? hdop;
        }

        // f[9] altitude
        if (f[9].isNotEmpty) {
          altitude = double.tryParse(f[9]) ?? altitude;
        }

        lastUpdate = DateTime.now();
        notifyListeners();
        return;
      }
    }

    // 3) NMEA GSA: PDOP/HDOP/VDOP + fix mode (M/A) & type (1/2/3D)
    if (line.startsWith('\$GPGSA') || line.startsWith('\$GNGSA')) {
      final f = line.split(',');
      if (f.length >= 18) {
        if (f[2].isNotEmpty) {
          final fixType = int.tryParse(f[2]); // 1/2/3
          // We don't overwrite solution with GSA 3D/2D, as GGA provides quality (Fixed/Float).
          // We only set INVALID if there is no fix.
          if (fixType == 1) {
            solution = 'INVALID';
          }
        }
        if (f[15].isNotEmpty) pdop = double.tryParse(f[15]) ?? pdop;
        if (f[16].isNotEmpty) hdop = double.tryParse(f[16]) ?? hdop;
        if (f[17].isNotEmpty) {
          final vd = f[17].split('*').first;
          vdop = double.tryParse(vd) ?? vdop;
        }
        lastUpdate = DateTime.now();
        notifyListeners();
      }
    }

    // 4) NMEA GSV: Satellites in View
    // $GPGSV, NoMsg, MsgNo, SatsInView, ...
    if (line.contains('GSV')) {
      final f = line.split(',');
      if (f.length >= 4) {
        // Field 3 is number of satellites in view
        if (f[3].isNotEmpty) {
          satsInView = int.tryParse(f[3]) ?? satsInView;
          notifyListeners();
        }
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
      0 => 'INVALID',
      1 => 'SINGLE',
      2 => 'DGNSS',
      4 => 'FIXED',
      5 => 'FLOAT',
      6 => 'DR',
      _ => solution ?? 'UNKNOWN'
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
