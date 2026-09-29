import 'dart:math' as math;

/// EPSG:5235 — SLD99 / Sri Lanka Grid 1999.
///
/// WGS84 ⇄ SLD99 datum shift (7-parameter Helmert, coordinate-frame
/// convention, EPSG towgs84) + Transverse Mercator on the Everest 1830
/// (1937 adjustment) ellipsoid. Matches PROJ's EPSG:4326 → EPSG:5235.
class Sld99Converter {
  // ── Ellipsoids ───────────────────────────────────────────────────────
  static const double _aW = 6378137.0; // WGS84
  static const double _fW = 1.0 / 298.257223563;
  static const double _a = 6377276.345; // Everest 1830 (1937 adj.)
  static const double _f = 1.0 / 300.8017;

  // ── SLD99 → WGS84 Helmert (towgs84), coordinate frame ────────────────
  static const double _tx = -0.293, _ty = 766.95, _tz = 87.713; // m
  static const double _rx = -0.195704, _ry = -1.695068, _rz = -3.473016; // "
  static const double _ds = -0.039338; // ppm

  // ── Transverse Mercator parameters ───────────────────────────────────
  static const double _k0 = 0.9999238418;
  static const double _lat0 = 7.00047152777778; // 7°00'01.6975" N
  static const double _lon0 = 80.7717130833333; // 80°46'18.1671" E
  static const double _falseE = 500000.0;
  static const double _falseN = 500000.0;

  static const double _deg = math.pi / 180.0;
  static const double _sec = math.pi / (180.0 * 3600.0);

  static double get _e2 => 2 * _f - _f * _f;
  static double get _ep2 => _e2 / (1 - _e2);

  // ── Public API ───────────────────────────────────────────────────────

  /// WGS84 decimal degrees → SLD99 metres {easting, northing}.
  static Map<String, double> toSld99(double lat, double lon,
      [double height = 0.0]) {
    final w = _toEcef(lat, lon, height, _aW, _fW);
    final s = _helmert(w, inverse: true);
    final g = _fromEcef(s, _a, _f);
    return _tmForward(g[0], g[1]);
  }

  /// SLD99 metres → WGS84 decimal degrees {lat, lon}.
  static Map<String, double> toWgs84(double easting, double northing) {
    final g = _tmInverse(easting, northing);
    final s = _toEcef(g[0], g[1], 0.0, _a, _f);
    final w = _helmert(s, inverse: false);
    final r = _fromEcef(w, _aW, _fW);
    return {'lat': r[0], 'lon': r[1]};
  }

  // ── Datum shift ──────────────────────────────────────────────────────

  static List<double> _toEcef(
      double latDeg, double lonDeg, double h, double a, double f) {
    final e2 = 2 * f - f * f;
    final phi = latDeg * _deg, lam = lonDeg * _deg;
    final n = a / math.sqrt(1 - e2 * math.sin(phi) * math.sin(phi));
    return [
      (n + h) * math.cos(phi) * math.cos(lam),
      (n + h) * math.cos(phi) * math.sin(lam),
      (n * (1 - e2) + h) * math.sin(phi),
    ];
  }

  /// ECEF → [latDeg, lonDeg, h] (iterative).
  static List<double> _fromEcef(List<double> p, double a, double f) {
    final e2 = 2 * f - f * f;
    final x = p[0], y = p[1], z = p[2];
    final lam = math.atan2(y, x);
    final r = math.sqrt(x * x + y * y);
    var phi = math.atan2(z, r * (1 - e2));
    var h = 0.0;
    for (var i = 0; i < 10; i++) {
      final n = a / math.sqrt(1 - e2 * math.sin(phi) * math.sin(phi));
      h = r / math.cos(phi) - n;
      final next = math.atan2(z, r * (1 - e2 * n / (n + h)));
      if ((next - phi).abs() < 1e-14) {
        phi = next;
        break;
      }
      phi = next;
    }
    return [phi / _deg, lam / _deg, h];
  }

  /// SLD99 → WGS84 (forward) or WGS84 → SLD99 (inverse), coordinate
  /// frame rotation convention, same as PROJ.
  static List<double> _helmert(List<double> p, {required bool inverse}) {
    final rx = _rx * _sec, ry = _ry * _sec, rz = _rz * _sec;
    final m = 1 + _ds * 1e-6;
    // Coordinate-frame rotation matrix (small angles)
    final r = [
      [1.0, rz, -ry],
      [-rz, 1.0, rx],
      [ry, -rx, 1.0],
    ];
    if (!inverse) {
      return [
        _tx + m * (r[0][0] * p[0] + r[0][1] * p[1] + r[0][2] * p[2]),
        _ty + m * (r[1][0] * p[0] + r[1][1] * p[1] + r[1][2] * p[2]),
        _tz + m * (r[2][0] * p[0] + r[2][1] * p[1] + r[2][2] * p[2]),
      ];
    }
    // Inverse: R^T (p - T) / m
    final q = [p[0] - _tx, p[1] - _ty, p[2] - _tz];
    return [
      (r[0][0] * q[0] + r[1][0] * q[1] + r[2][0] * q[2]) / m,
      (r[0][1] * q[0] + r[1][1] * q[1] + r[2][1] * q[2]) / m,
      (r[0][2] * q[0] + r[1][2] * q[1] + r[2][2] * q[2]) / m,
    ];
  }

  // ── Transverse Mercator on Everest 1830 ──────────────────────────────

  // Meridian arc from equator to latitude phi (radians)
  static double _M(double phi) {
    final e2 = _e2;
    final e4 = e2 * e2;
    final e6 = e4 * e2;
    return _a *
        ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi -
            (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi) +
            (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi) -
            (35 * e6 / 3072) * math.sin(6 * phi));
  }

  static Map<String, double> _tmForward(double lat, double lon) {
    final phi = lat * _deg;
    final lam = (lon - _lon0) * _deg;
    const phi0 = _lat0 * _deg;

    final sinP = math.sin(phi);
    final cosP = math.cos(phi);
    final tanP = math.tan(phi);

    final N = _a / math.sqrt(1 - _e2 * sinP * sinP);
    final T = tanP * tanP;
    final C = _ep2 * cosP * cosP;
    final A = cosP * lam;

    final A2 = A * A, A3 = A2 * A, A4 = A3 * A, A5 = A4 * A, A6 = A5 * A;

    final x = _k0 *
        N *
        (A +
            (1 - T + C) * A3 / 6.0 +
            (5 - 18 * T + T * T + 72 * C - 58 * _ep2) * A5 / 120.0);

    final y = _k0 *
        (_M(phi) -
            _M(phi0) +
            N *
                tanP *
                (A2 / 2.0 +
                    (5 - T + 9 * C + 4 * C * C) * A4 / 24.0 +
                    (61 - 58 * T + T * T + 600 * C - 330 * _ep2) *
                        A6 /
                        720.0));

    return {'easting': x + _falseE, 'northing': y + _falseN};
  }

  /// → [latDeg, lonDeg] on Everest 1830.
  static List<double> _tmInverse(double easting, double northing) {
    final x = easting - _falseE;
    final y = northing - _falseN;

    const phi0 = _lat0 * _deg;
    final e2 = _e2;
    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final e12 = e1 * e1, e13 = e12 * e1, e14 = e13 * e1;

    final mv = _M(phi0) + y / _k0;
    final mu =
        mv / (_a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

    // Footpoint latitude
    final phi1 = mu +
        (3 * e1 / 2 - 27 * e13 / 32) * math.sin(2 * mu) +
        (21 * e12 / 16 - 55 * e14 / 32) * math.sin(4 * mu) +
        (151 * e13 / 96) * math.sin(6 * mu) +
        (1097 * e14 / 512) * math.sin(8 * mu);

    final sinP1 = math.sin(phi1);
    final cosP1 = math.cos(phi1);
    final tanP1 = math.tan(phi1);

    final n1 = _a / math.sqrt(1 - e2 * sinP1 * sinP1);
    final r1 = _a * (1 - e2) / math.pow(1 - e2 * sinP1 * sinP1, 1.5);
    final d = x / (n1 * _k0);
    final t1 = tanP1 * tanP1;
    final c1 = _ep2 * cosP1 * cosP1;

    final d2 = d * d, d3 = d2 * d, d4 = d3 * d, d5 = d4 * d, d6 = d5 * d;

    final phi = phi1 -
        (n1 * tanP1 / r1) *
            (d2 / 2.0 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * _ep2) * d4 / 24.0 +
                (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * _ep2 -
                        3 * c1 * c1) *
                    d6 /
                    720.0);

    final lam = (d -
            (1 + 2 * t1 + c1) * d3 / 6.0 +
            (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * _ep2 + 24 * t1 * t1) *
                d5 /
                120.0) /
        cosP1;

    return [phi / _deg, _lon0 + lam / _deg];
  }
}
