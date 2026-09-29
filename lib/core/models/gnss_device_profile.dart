import 'dart:math' as math;

enum GnssDeviceType { vertextV2, stonexS900A, generic }

class GnssDeviceProfile {
  final String manufacturer;
  final String model;
  final GnssDeviceType type;
  // Phase centre offset above Antenna Reference Point (ARP) in metres.
  // Applied to: correctedHeight = gnssAlt - instrumentHeight + phaseCentreOffset
  final double phaseCentreOffset;
  final bool hasTiltSensor;
  final bool hasSdCard;
  final bool hasStaticMode;
  // Typical BT device name fragment for auto-match
  final String btNameHint;

  const GnssDeviceProfile({
    required this.manufacturer,
    required this.model,
    required this.type,
    this.phaseCentreOffset = 0.0,
    this.hasTiltSensor = false,
    this.hasSdCard = false,
    this.hasStaticMode = false,
    this.btNameHint = '',
  });

  String get displayName => '$manufacturer $model';
}

// ── Built-in device catalogue ─────────────────────────────────────────────────

const GnssDeviceProfile kVertextV2 = GnssDeviceProfile(
  manufacturer: 'VerText',
  model: 'V2',
  type: GnssDeviceType.vertextV2,
  phaseCentreOffset: 0.0,
  hasTiltSensor: true,
  hasSdCard: true,
  hasStaticMode: true,
  btNameHint: 'VertextT',
);

// Stonex S900A L1/L2 RTK GNSS Receiver
// ARP to L1 phase centre: ~0.0813 m (from Stonex IGS ANTEX)
const GnssDeviceProfile kStonexS900A = GnssDeviceProfile(
  manufacturer: 'Stonex',
  model: 'S900A',
  type: GnssDeviceType.stonexS900A,
  phaseCentreOffset: 0.0813,
  hasTiltSensor: false,
  hasSdCard: false,
  hasStaticMode: false,
  btNameHint: 'S900',
);

const GnssDeviceProfile kGeneric = GnssDeviceProfile(
  manufacturer: 'Generic',
  model: 'GNSS Receiver',
  type: GnssDeviceType.generic,
  phaseCentreOffset: 0.0,
  hasTiltSensor: false,
  hasSdCard: false,
  hasStaticMode: false,
);

const List<GnssDeviceProfile> kDeviceCatalogue = [
  kVertextV2,
  kStonexS900A,
  kGeneric,
];

// ── Tilt-corrected height calculation ─────────────────────────────────────────

/// Returns the corrected instrument height when the pole is tilted.
/// [poleHeight]: vertical pole height entered by user (metres)
/// [rollDeg], [pitchDeg]: IMU-derived roll and pitch (degrees)
double tiltCorrectedHI(double poleHeight, double rollDeg, double pitchDeg) {
  final tiltRad = math.sqrt(
        math.pow(rollDeg * math.pi / 180, 2) +
        math.pow(pitchDeg * math.pi / 180, 2));
  return poleHeight * math.cos(tiltRad);
}

/// Returns total tilt angle in degrees from vertical.
double totalTiltDeg(double rollDeg, double pitchDeg) {
  return math.sqrt(rollDeg * rollDeg + pitchDeg * pitchDeg);
}

/// Returns corrected ellipsoidal height:
/// gnssAlt − correctedHI + phaseCentreOffset
double correctedEllipsoidalHeight({
  required double gnssAlt,
  required double correctedHI,
  required double phaseCentreOffset,
}) {
  return gnssAlt - correctedHI + phaseCentreOffset;
}
