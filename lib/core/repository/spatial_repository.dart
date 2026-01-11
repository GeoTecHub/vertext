import '../api/api_service.dart';

class SpatialRepository {
  final _api = ApiService();

  Future<List<Map<String,dynamic>>> listByProject(int projectId) =>
      _api.getSpatialByProject(projectId);

  Future<Map<String,dynamic>> create({
    required int projectId,
    required int layerId,
    required Map<String,dynamic> geometry,
    required Map<String,dynamic> attributes,
  }) =>
      _api.createSpatial(
        projectId: projectId,
        layerId: layerId,
        geometry: geometry,
        attributes: attributes,
      );

  Future<Map<String,dynamic>> update(
    int id, {
    Map<String,dynamic>? geometry,
    Map<String,dynamic>? attributes,
  }) =>
      _api.updateSpatial(id, geometry: geometry, attributes: attributes);
}
