import 'package:flutter/foundation.dart';
import '../../core/models/layer.dart';
import '../../core/repository/layer_repository.dart';

class LayersViewModel extends ChangeNotifier {
  final _repo = LayerRepository();
  bool loading = false;
  String? error;
  List<LayerModel> items = [];

  Future<void> refresh() async {
    loading = true; error = null; notifyListeners();
    try {
      items = await _repo.list();
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  Future<void> add(String name, String colour) async {
    loading = true; notifyListeners();
    try {
      final l = await _repo.create(name, colour);
      items = [...items, l];
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  Future<void> edit(int id, {String? name, String? colour}) async {
    loading = true; notifyListeners();
    try {
      final updated = await _repo.update(id, name: name, colour: colour);
      items = items.map((e) => e.layerId == id ? updated : e).toList();
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  Future<void> remove(int id) async {
    loading = true; notifyListeners();
    try {
      final ok = await _repo.delete(id);
      if (ok) items = items.where((e) => e.layerId != id).toList();
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }
}
