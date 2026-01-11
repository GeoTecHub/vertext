import 'package:flutter/foundation.dart';
import '../../core/repository/spatial_repository.dart';

class SpatialViewModel extends ChangeNotifier {
  final _repo = SpatialRepository();
  bool loading = false;
  String? error;
  List<Map<String,dynamic>> features = [];

  Future<void> load(int projectId) async {
    loading = true; error = null; notifyListeners();
    try {
      features = await _repo.listByProject(projectId);
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  Future<void> addPoint({
    required int projectId, required int layerId,
    required double lon, required double lat, Map<String,dynamic>? attrs,
  }) async {
    loading = true; notifyListeners();
    try {
      final geom = {"type":"Point","coordinates":[lon,lat]};
      final created = await _repo.create(
        projectId: projectId, layerId: layerId, geometry: geom, attributes: attrs ?? {});
      features = [...features, created];
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }
}
