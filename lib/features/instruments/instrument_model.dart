import '../../core/models/gnss_device_profile.dart';

class InstrumentModel {
  final String id;
  String manufacturer;
  String model;
  double phaseCentreOffset;
  bool hasTiltSensor;
  bool hasSdCard;
  bool hasStaticMode;
  String btNameHint;
  final bool isBuiltIn;

  InstrumentModel({
    required this.id,
    required this.manufacturer,
    required this.model,
    this.phaseCentreOffset = 0.0,
    this.hasTiltSensor = false,
    this.hasSdCard = false,
    this.hasStaticMode = false,
    this.btNameHint = '',
    this.isBuiltIn = false,
  });

  String get displayName => '$manufacturer $model';

  GnssDeviceProfile toGnssDeviceProfile() => GnssDeviceProfile(
        manufacturer: manufacturer,
        model: model,
        type: GnssDeviceType.generic,
        phaseCentreOffset: phaseCentreOffset,
        hasTiltSensor: hasTiltSensor,
        hasSdCard: hasSdCard,
        hasStaticMode: hasStaticMode,
        btNameHint: btNameHint,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'manufacturer': manufacturer,
        'model': model,
        'pco': phaseCentreOffset,
        'hasTiltSensor': hasTiltSensor,
        'hasSdCard': hasSdCard,
        'hasStaticMode': hasStaticMode,
        'btNameHint': btNameHint,
        'isBuiltIn': isBuiltIn,
      };

  factory InstrumentModel.fromJson(Map<String, dynamic> json) =>
      InstrumentModel(
        id: json['id'] as String,
        manufacturer: json['manufacturer'] as String,
        model: json['model'] as String,
        phaseCentreOffset: (json['pco'] as num).toDouble(),
        hasTiltSensor: json['hasTiltSensor'] as bool? ?? false,
        hasSdCard: json['hasSdCard'] as bool? ?? false,
        hasStaticMode: json['hasStaticMode'] as bool? ?? false,
        btNameHint: json['btNameHint'] as String? ?? '',
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      );

  InstrumentModel copyWith({
    String? manufacturer,
    String? model,
    double? phaseCentreOffset,
    bool? hasTiltSensor,
    bool? hasSdCard,
    bool? hasStaticMode,
    String? btNameHint,
  }) =>
      InstrumentModel(
        id: id,
        manufacturer: manufacturer ?? this.manufacturer,
        model: model ?? this.model,
        phaseCentreOffset: phaseCentreOffset ?? this.phaseCentreOffset,
        hasTiltSensor: hasTiltSensor ?? this.hasTiltSensor,
        hasSdCard: hasSdCard ?? this.hasSdCard,
        hasStaticMode: hasStaticMode ?? this.hasStaticMode,
        btNameHint: btNameHint ?? this.btNameHint,
        isBuiltIn: isBuiltIn,
      );
}

// ── Default built-in instruments ──────────────────────────────────────────────

final kDefaultInstruments = <InstrumentModel>[
  InstrumentModel(
    id: 'vertext_v2',
    manufacturer: 'VerText',
    model: 'V2',
    phaseCentreOffset: 0.0,
    hasTiltSensor: true,
    hasSdCard: true,
    hasStaticMode: true,
    btNameHint: 'VertextT',
    isBuiltIn: true,
  ),
  InstrumentModel(
    id: 'stonex_s900a',
    manufacturer: 'Stonex',
    model: 'S900A',
    phaseCentreOffset: 0.0813,
    hasTiltSensor: false,
    hasSdCard: false,
    hasStaticMode: false,
    btNameHint: 'S900',
    isBuiltIn: true,
  ),
  InstrumentModel(
    id: 'stonex_cube',
    manufacturer: 'Stonex',
    model: 'Cube',
    phaseCentreOffset: 0.0680,
    hasTiltSensor: true,
    hasSdCard: false,
    hasStaticMode: false,
    btNameHint: 'Cube',
    isBuiltIn: true,
  ),
  InstrumentModel(
    id: 'generic',
    manufacturer: 'Generic',
    model: 'GNSS Receiver',
    phaseCentreOffset: 0.0,
    hasTiltSensor: false,
    hasSdCard: false,
    hasStaticMode: false,
    btNameHint: '',
    isBuiltIn: true,
  ),
];
