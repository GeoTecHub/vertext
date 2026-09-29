/// A row from a lookup endpoint (DSD, GND, org members), normalised for
/// pickers. The API returns untyped rows, so several key spellings are
/// accepted.
class LookupItem {
  final int? id;
  final String label;

  /// Value used to query dependent lists (e.g. DSD name for gnd_data?dsd=).
  final String value;

  const LookupItem({this.id, required this.label, required this.value});

  factory LookupItem.dsd(dynamic row) {
    if (row is! Map) return LookupItem(label: '$row', value: '$row');
    final name = _str(row, const ['dsd', 'dsd_name', 'dsd_n', 'name']) ?? '';
    return LookupItem(
        id: _int(row, const ['dsd_id', 'id']), label: name, value: name);
  }

  factory LookupItem.gnd(dynamic row) {
    if (row is! Map) {
      return LookupItem(id: int.tryParse('$row'), label: '$row', value: '$row');
    }
    final id = _int(row, const ['gnd_id', 'id', 'gid']);
    final name =
        _str(row, const ['gnd', 'gnd_name', 'gnd_n', 'name']) ?? 'GND $id';
    final code = _str(row, const ['gnd_code', 'code', 'gnd_no']);
    return LookupItem(
        id: id, label: code == null ? name : '$name ($code)', value: name);
  }

  factory LookupItem.member(dynamic row) {
    if (row is! Map) return LookupItem(label: '$row', value: '$row');
    final id = _int(row, const ['user_id', 'id']);
    final full = [
      _str(row, const ['first_name']),
      _str(row, const ['last_name']),
    ].whereType<String>().join(' ');
    final label = _str(row, const ['display_name']) ??
        (full.isNotEmpty ? full : null) ??
        _str(row, const ['username', 'email']) ??
        'User $id';
    return LookupItem(id: id, label: label, value: label);
  }

  static String? _str(Map row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return null;
  }

  static int? _int(Map row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v is num) return v.toInt();
      if (v is String && int.tryParse(v) != null) return int.parse(v);
    }
    return null;
  }
}
