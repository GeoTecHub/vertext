import 'package:flutter_test/flutter_test.dart';
import 'package:vertext_flutter/utils/sld99_converter.dart';

void main() {
  // [lat, lon, easting, northing] — reference values from PROJ
  // (pyproj 3.7, EPSG:4326 → EPSG:5235).
  const ref = [
    [6.7100679, 80.7901863, 501818.4539, 467850.5058],
    [6.9271, 79.8612, 399158.5936, 491947.3148],
    [9.6615, 80.0255, 417887.3171, 794330.7327],
    [6.0329, 80.2168, 438347.3102, 393002.5868],
    [7.2906, 80.6337, 484538.0795, 532048.6108],
    [8.5874, 81.2152, 548593.3110, 675480.9842],
    [7.8731, 81.6747, 599351.2281, 596567.4673],
  ];

  test('WGS84 → SLD99 matches PROJ within 1 cm', () {
    for (final r in ref) {
      final s = Sld99Converter.toSld99(r[0], r[1]);
      expect(s['easting']!, closeTo(r[2], 0.01), reason: 'E at ${r[0]},${r[1]}');
      expect(s['northing']!, closeTo(r[3], 0.01), reason: 'N at ${r[0]},${r[1]}');
    }
  });

  test('SLD99 → WGS84 matches PROJ within ~1 cm', () {
    for (final r in ref) {
      final g = Sld99Converter.toWgs84(r[2], r[3]);
      expect(g['lat']!, closeTo(r[0], 1e-7), reason: 'lat at ${r[2]},${r[3]}');
      expect(g['lon']!, closeTo(r[1], 1e-7), reason: 'lon at ${r[2]},${r[3]}');
    }
  });
}
