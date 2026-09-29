import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../gnss/gnss_live_viewmodel.dart';
import '../../projects/projects_viewmodel.dart';
import '../../projects/points_viewmodel.dart';
import '../../ntrip/ntrip_viewmodel.dart';
import '../../../core/models/project.dart';
import '../../bluetooth/bt_viewmodel.dart';
import '../../../app.dart';
import '../../../utils/sld99_converter.dart';

class HomeInfoBar extends StatelessWidget {
  const HomeInfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gnss = context.watch<GnssLiveViewModel>();
    final bt = context.watch<BtViewModel>();
    final projectsVM = context.watch<ProjectsViewModel>();
    final pointsVM = context.watch<PointsViewModel>();
    final ntrip = context.watch<NtripViewModel>();

    final selectedProject = projectsVM.items.cast<ProjectModel?>().firstWhere(
        (p) => p?.projectId?.toString() == projectsVM.selectedProjectId,
        orElse: () => null);

    final projName = selectedProject?.projectName ?? 'No Project';
    final pointsCount = pointsVM.points.length;

    String sldN = '?';
    String sldE = '?';
    if (gnss.position != null) {
      final sld = Sld99Converter.toSld99(
          gnss.position!.latitude, gnss.position!.longitude);
      sldN = sld['northing']!.toStringAsFixed(3);
      sldE = sld['easting']!.toStringAsFixed(3);
    }
    final corrH = bt.correctedEllipsoidHeight;
    final elev = corrH != null
        ? corrH.toStringAsFixed(3)
        : gnss.altitude?.toStringAsFixed(3) ?? '?';

    String baseDist = '?';
    if (gnss.position != null && ntrip.basePosition != null) {
      final d = const Distance()
          .as(LengthUnit.Meter, gnss.position!, ntrip.basePosition!);
      baseDist = d < 1000
          ? '${d.toStringAsFixed(1)} m'
          : '${(d / 1000.0).toStringAsFixed(2)} km';
    }

    final sol = gnss.solution ?? 'NO FIX';
    Color solColor = const Color(0xFF546E7A);
    if (sol.contains('FIXED')) {
      solColor = kCubeFixGreen;
    } else if (sol.contains('FLOAT') || sol.contains('DGNSS')) {
      solColor = const Color(0xFFE65100);
    } else if (sol.contains('SINGLE')) {
      solColor = kCubeNoFixRed;
    }

    return Container(
      color: const Color(0xFF0D2D54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project + point count row
          Row(
            children: [
              const Icon(Icons.folder_open, color: Colors.white60, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  projName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Pts: $pointsCount',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 5),

          // SLD99 projected coordinates
          Row(
            children: [
              _CoordCell(label: 'N', value: sldN),
              const SizedBox(width: 8),
              _CoordCell(label: 'E', value: sldE),
              const SizedBox(width: 8),
              _CoordCell(label: 'Z', value: elev),
            ],
          ),

          const SizedBox(height: 5),

          // Solution + base dist row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: solColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  sol,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.satellite_alt, color: Colors.white60, size: 13),
              const SizedBox(width: 4),
              Text(
                '${gnss.satsInUse ?? '-'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.cell_tower, color: Colors.white60, size: 13),
              const SizedBox(width: 4),
              Text(
                baseDist,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoordCell extends StatelessWidget {
  final String label;
  final String value;
  const _CoordCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}
