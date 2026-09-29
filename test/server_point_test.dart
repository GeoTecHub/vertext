import 'package:flutter_test/flutter_test.dart';
import 'package:vertext_flutter/core/models/point.dart';
import 'package:vertext_flutter/core/models/spatial_data_model.dart';
import 'package:vertext_flutter/core/repository/spatial_repository.dart';

void main() {
  // One feature as returned by GET user/spatialdata/project_id=7/
  final feature = <String, dynamic>{
    'id': 30169,
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [80.79019236666667, 6.7101197, 592.8],
    },
    'properties': {
      'layer_name': 'Land',
      'spatial_uuid': '04b2dc11-f168-417d-b3a4-be023a2219ef',
      'user_id': 16,
      'type': 'point',
      'area': null,
      'date_created': '2026-09-29T15:40:11.418078+05:30',
      'ref_coordinate': {
        'type': 'Point',
        'coordinates': [501819.12446944433, 467856.2338673735, 592.8],
      },
      'point_no': 5,
      'point_code': 'Te',
      'hdop': '0.870',
      'pdop': '1.610',
      'vdop': '1.360',
      'hrms': null,
      'vrms': null,
      'inst_height': '1.8000',
      'mode_status': 'RTK Fixed',
      'done_by': 'Chathura Dulanga',
      'project_id': 7,
      'layer_id': 1,
    },
  };

  test('server feature -> PointModel', () {
    final p = PointModel.fromServerFeature(feature, '7')!;
    expect(p.serverId, 30169);
    expect(p.name, '5');
    expect(p.code, 'Te');
    expect(p.latitude, 6.7101197);
    expect(p.altitude, 592.8);
    expect(p.hdop, 0.87); // server sends decimals as strings
    expect(p.instrumentHeight, 1.8);
    expect(p.solutionType, 'RTK Fixed');
    expect(p.layerName, 'Land');
    expect(p.doneBy, 'Chathura Dulanga');
    expect(p.refEasting, closeTo(501819.124, 0.001));
    expect(p.fromServer, isTrue);

    // Survives local save/load
    final back = PointModel.fromJson(p.toJson());
    expect(back.doneBy, 'Chathura Dulanga');
    expect(back.serverCreated, p.serverCreated);
    expect(back.fromServer, isTrue);
  });

  test('id and point number helpers read GeoJSON features', () {
    expect(SpatialRepository.featureId(feature), 30169);
    expect(SpatialRepository.featurePointNo(feature), 5);
    expect(SpatialRepository.featureLonLat(feature),
        [80.79019236666667, 6.7101197]);
  });

  test('upload uses the server field names', () {
    final json = SpatialProperties(
      projectId: 7,
      layerId: 1,
      pointNo: 5,
      pointCode: 'Te',
      instrumentHight: '1.8000',
      modeStatus: 'RTK Fixed',
      hrms: 0.01,
      vrms: 0.02,
    ).toJson();
    expect(json['inst_height'], '1.800');
    expect(json['mode_status'], 'RTK Fixed');
    expect(json['hrms'], 0.01);
    expect(json['vrms'], 0.02);
  });

  test('decimal fields never exceed 3 decimal places', () {
    final json = SpatialProperties(
      projectId: 7,
      layerId: 1,
      pointNo: 6,
      instrumentHight: '1.8000',
      hdop: 0.87654,
      pdop: 1.23456,
      vdop: 1.0,
      hrms: 0.0123456,
      vrms: 0.0198765,
    ).toJson();
    expect(json['inst_height'], '1.800');
    expect(json['instrument_hight'], '1.800');
    expect(json['hdop'], 0.877);
    expect(json['pdop'], 1.235);
    expect(json['hrms'], 0.012);
    expect(json['vrms'], 0.02);
  });
}
