import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class LiveBus {
  // current GNSS position (null until first fix)
  static final ValueNotifier<LatLng?> pos = ValueNotifier<LatLng?>(null);

  // last raw line seen (JSON/NMEA) for quick debug
  static final ValueNotifier<String?> lastLine = ValueNotifier<String?>(null);
}
