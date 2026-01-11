import '../api/api_service.dart';
import '../models/layer.dart';

class LayerRepository {
  final ApiService _api = ApiService();

  Future<List<LayerModel>> list() => _api.getLayers();

  // Back-compat for HomeViewModel (calls getLayers)
  Future<List<LayerModel>> getLayers() => _api.getLayers();

  Future<LayerModel> create(String name, String colour) =>
      _api.createLayer(name: name, colour: colour);

  Future<LayerModel> update(int id, {String? name, String? colour}) =>
      _api.updateLayer(id: id, name: name, colour: colour);

  Future<bool> delete(int id) => _api.deleteLayer(id);
}
