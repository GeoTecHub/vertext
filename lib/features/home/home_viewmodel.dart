import 'package:flutter/foundation.dart';
import '../../core/models/layer.dart';
import '../../core/repository/layer_repository.dart';
import '../../core/storage/storage_helper.dart';

class HomeViewModel extends ChangeNotifier {
  final _repo = LayerRepository();
  bool loading = false;
  List<LayerModel> layers = [];
  String? error;

  Future<void> loadLayers() async {
    loading = true; error = null; notifyListeners();
    try {
      layers = await _repo.getLayers();
      if (layers.isNotEmpty) {
        await StorageHelper.saveLayer(layers.first);
      }
      loading = false; notifyListeners();
    } catch (e) {
      error = e.toString();
      loading = false; notifyListeners();
    }
  }
}
