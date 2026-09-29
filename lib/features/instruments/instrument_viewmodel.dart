import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'instrument_model.dart';
import '../bluetooth/bt_viewmodel.dart';

class InstrumentViewModel extends ChangeNotifier {
  static const _kListKey = 'instruments_list_v1';
  static const _kSelectedKey = 'instruments_selected_id';

  List<InstrumentModel> _instruments = [];
  String _selectedId = 'vertext_v2';
  bool _loaded = false;

  List<InstrumentModel> get instruments => List.unmodifiable(_instruments);
  bool get loaded => _loaded;

  InstrumentModel get selected {
    if (_instruments.isEmpty) return kDefaultInstruments.first;
    return _instruments.firstWhere(
      (i) => i.id == _selectedId,
      orElse: () => _instruments.first,
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedId = prefs.getString(_kSelectedKey) ?? 'vertext_v2';
    final raw = prefs.getString(_kListKey);

    if (raw == null) {
      _instruments = kDefaultInstruments.map((d) => d.copyWith()).toList();
    } else {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _instruments = list
            .map((e) => InstrumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // Seed any newly added built-ins not yet in storage
        for (final def in kDefaultInstruments) {
          if (!_instruments.any((i) => i.id == def.id)) {
            final insertAt = kDefaultInstruments.indexOf(def);
            _instruments.insert(insertAt.clamp(0, _instruments.length), def.copyWith());
          }
        }
      } catch (_) {
        _instruments = kDefaultInstruments.map((d) => d.copyWith()).toList();
      }
    }

    _loaded = true;
    _syncToBt();
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    _syncToBt();
    _save();
    notifyListeners();
  }

  void addInstrument(InstrumentModel inst) {
    _instruments.add(inst);
    _save();
    notifyListeners();
  }

  void updateInstrument(InstrumentModel updated) {
    final idx = _instruments.indexWhere((i) => i.id == updated.id);
    if (idx < 0) return;
    _instruments[idx] = updated;
    if (updated.id == _selectedId) _syncToBt();
    _save();
    notifyListeners();
  }

  void deleteInstrument(String id) {
    final inst = _instruments.firstWhere((i) => i.id == id, orElse: () => _instruments.first);
    if (inst.isBuiltIn) return; // built-ins cannot be deleted
    _instruments.removeWhere((i) => i.id == id);
    if (_selectedId == id) {
      _selectedId = _instruments.first.id;
      _syncToBt();
    }
    _save();
    notifyListeners();
  }

  void _syncToBt() {
    BtViewModel.instance.setDevice(selected.toGnssDeviceProfile());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kListKey, jsonEncode(_instruments.map((i) => i.toJson()).toList()));
    await prefs.setString(_kSelectedKey, _selectedId);
  }

  /// Generates a unique ID for a new custom instrument.
  static String newId() =>
      'custom_${DateTime.now().millisecondsSinceEpoch}';
}
