import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bluetooth/bt_viewmodel.dart';
import '../../gnss/gnss_live_viewmodel.dart';
import '../../../app.dart';

class HomeHeader extends StatelessWidget {
  final bool showBackButton;
  const HomeHeader({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BtViewModel>();
    final gnss = context.watch<GnssLiveViewModel>();

    final sol = gnss.solution?.toUpperCase() ?? 'NO FIX';
    final isFixed = sol.contains('FIXED') || sol.contains('FLOAT') ||
        sol.contains('DGNSS') || sol.contains('SINGLE');
    final fixColor = sol.contains('FIXED')
        ? kCubeFixGreen
        : sol.contains('FLOAT') || sol.contains('DGNSS')
            ? const Color(0xFFE65100)
            : kCubeNoFixRed;

    final hdop = gnss.hdop?.toStringAsFixed(2) ?? 'NA';
    final vdop = gnss.vdop?.toStringAsFixed(2) ?? 'NA';
    final satsInUse = gnss.satsInUse ?? 0;
    final lat = gnss.position?.latitude;
    final lon = gnss.position?.longitude;
    final alt = gnss.altitude;

    final nStr = lat != null ? lat.toStringAsFixed(4) : '?';
    final eStr = lon != null ? lon.toStringAsFixed(4) : '?';
    final zStr = alt != null ? alt.toStringAsFixed(3) : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Status row ──────────────────────────────────────────────────
        Container(
          color: kCubeBlue,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button OR spacer
                if (showBackButton)
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                  )
                else
                  const SizedBox(width: 28),

                // Fix quality box
                Container(
                  width: 90,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: fixColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sol.contains('FIXED')
                            ? 'RTK FIXED'
                            : sol.contains('FLOAT')
                                ? 'RTK FLOAT'
                                : sol.contains('SINGLE')
                                    ? 'SINGLE'
                                    : 'NO FIX',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text('H: $hdop',
                          style: TextStyle(
                              color: isFixed ? Colors.white : Colors.red[200],
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      Text('V: $vdop',
                          style: TextStyle(
                              color: isFixed ? Colors.white : Colors.red[200],
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Center: Fix status + satellites
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sol,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.satellite_alt,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text('$satsInUse',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right: WiFi + Battery indicator
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WifiStatusIcon(connected: bt.connected),
                    const SizedBox(height: 4),
                    const Icon(Icons.battery_full,
                        color: Colors.white70, size: 18),
                  ],
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),

        // ── Coordinate row ───────────────────────────────────────────────
        Container(
          color: kCubeCoordBar,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
              Expanded(
                child: Text(
                  'N $nStr   E $eStr   Z $zStr',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _WifiStatusIcon extends StatelessWidget {
  final bool connected;
  const _WifiStatusIcon({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: connected ? Colors.green[700] : const Color(0xFFFFAA00),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi, color: Colors.white, size: 16),
        ),
        if (!connected)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 8),
            ),
          ),
      ],
    );
  }
}
