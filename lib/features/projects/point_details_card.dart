import 'package:flutter/material.dart';
import '../../core/models/point.dart';
import '../../utils/sld99_converter.dart';

/// Shows the saved-point details popup (same layout as the web app).
Future<void> showPointDetails(BuildContext context, PointModel p) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: PointDetailsCard(point: p)),
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PointDetailsCard extends StatelessWidget {
  final PointModel point;
  const PointDetailsCard({super.key, required this.point});

  static const _header = Color(0xFF283593);
  static const _label = Color(0xFF6B7280);
  static const _section = Color(0xFFF3F4F6);

  static String _n(double? v, int digits) =>
      v == null ? '—' : v.toStringAsFixed(digits);

  static String _s(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  @override
  Widget build(BuildContext context) {
    final p = point;
    final sld = Sld99Converter.toSld99(p.latitude, p.longitude);
    final code = _s(p.code);
    String two(int v) => v.toString().padLeft(2, '0');
    String fmt(DateTime? d) {
      if (d == null) return '—';
      final t = d.toLocal();
      return '${t.year}-${two(t.month)}-${two(t.day)} '
          '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: _header,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'No: ${p.name}  |  Code: $code',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                p.serverId != null ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Point No.', p.name),
                _row('Point code', code),
                _row('Instrument height',
                    p.instrumentHeight == null
                        ? '—'
                        : '${_n(p.instrumentHeight, 3)} m'),
                _row('Mode status', _s(p.solutionType)),
                _gap(),
                _title('WGS84'),
                _row('X', _n(p.longitude, 7)),
                _row('Y', _n(p.latitude, 7)),
                _row('Z', _n(p.altitude, 3)),
                _gap(),
                _title('SLD99 (EPSG:5235)'),
                _row('Easting (E)', '${_n(sld['easting'], 3)} m'),
                _row('Northing (N)', '${_n(sld['northing'], 3)} m'),
                _row('Height', p.altitude == null ? '—' : '${_n(p.altitude, 3)} m'),
                _gap(),
                _row('HDOP', _n(p.hdop, 3)),
                _row('PDOP', _n(p.pdop, 3)),
                _row('VDOP', _n(p.vdop, 3)),
                _row('HRMS', _n(p.hrms, 3)),
                _row('VRMS', _n(p.vrms, 3)),
                _gap(),
                _row('Diff age', p.diffAge == null ? '—' : '${_n(p.diffAge, 1)} s'),
                _row('Base ID', _s(p.baseId)),
                _row(p.fromServer ? 'Measured / saved' : 'Measured',
                    fmt(p.timestamp)),
                _gap(),
                _title('SERVER'),
                _row('Status',
                    p.serverId == null
                        ? 'Not sent'
                        : p.pendingSync
                            ? 'Change waiting to upload'
                            : p.fromServer
                            ? 'Downloaded (id ${p.serverId})'
                            : 'Sent (id ${p.serverId})'),
                _row('Layer', _s(p.layerName ?? p.layerId?.toString())),
                _row('Collected by', _s(p.doneBy)),
                _row('Saved on server', fmt(p.serverCreated)),
                _row('UUID', _s(p.spatialUuid)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: _label, fontSize: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
            ),
          ],
        ),
      );

  Widget _title(String text) => Container(
        color: _section,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _header,
                letterSpacing: 0.3)),
      );

  Widget _gap() => const SizedBox(height: 10);
}
