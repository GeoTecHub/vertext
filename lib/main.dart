import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Use package: imports everywhere to avoid duplicate VM instances
import 'package:vertext_flutter/core/storage/session_manager.dart';

import 'package:vertext_flutter/features/auth/login_viewmodel.dart';
import 'package:vertext_flutter/features/home/home_viewmodel.dart';
import 'package:vertext_flutter/features/projects/create_project_viewmodel.dart';
import 'package:vertext_flutter/features/layers/layers_viewmodel.dart';
import 'package:vertext_flutter/features/projects/projects_viewmodel.dart';
import 'package:vertext_flutter/features/spatial/spatial_viewmodel.dart';
import 'package:vertext_flutter/features/ntrip/ntrip_viewmodel.dart';
import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';
import 'package:vertext_flutter/features/gnss/gnss_live_viewmodel.dart';
import 'package:vertext_flutter/features/plans/plan_management_viewmodel.dart';
import 'package:vertext_flutter/features/projects/points_viewmodel.dart';
import 'package:vertext_flutter/features/home/tolerance_viewmodel.dart';
import 'package:vertext_flutter/features/instruments/instrument_viewmodel.dart';

import 'package:vertext_flutter/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = SessionManager();
  final hasSession = await session.hasSession();

  // Load instrument list before app starts so BtViewModel has the right device
  final instrVM = InstrumentViewModel();
  await instrVM.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => CreateProjectViewModel()),
        ChangeNotifierProvider(create: (_) => LayersViewModel()),
        ChangeNotifierProvider(create: (_) => ProjectsViewModel()),
        ChangeNotifierProvider(create: (_) => SpatialViewModel()),
        ChangeNotifierProvider(create: (_) => NtripViewModel()),
        ChangeNotifierProvider(create: (_) => PlanManagementViewModel()),
        ChangeNotifierProvider(create: (_) => PointsViewModel()),
        ChangeNotifierProvider(create: (_) => ToleranceViewModel()),

        // Instrument catalogue (must be before BtViewModel)
        ChangeNotifierProvider<InstrumentViewModel>.value(value: instrVM),

        // Live GNSS + Bluetooth at the root (single instances app-wide)
        ChangeNotifierProvider(create: (_) => GnssLiveViewModel(), lazy: false),
        ChangeNotifierProvider(create: (_) => BtViewModel(), lazy: false),
      ],
      child: VerTextApp(startLoggedIn: hasSession),
    ),
  );
}
