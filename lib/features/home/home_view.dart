import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';

import 'home_viewmodel.dart';
import 'package:vertext_flutter/widgets/app_drawer.dart';
import 'package:vertext_flutter/features/bluetooth/bt_viewmodel.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final WebViewController _controller;
  bool _pageReady = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _pageReady = true;
            // ⚠️ Do not await before using context — avoids use_build_context_synchronously
            _controller.runJavaScript("window.setFollowMe(true);");
            if (!mounted) return;
            final bt = context.read<BtViewModel>();
            _pushToWeb(bt);
          },
        ),
      )
      ..loadFlutterAsset('assets/map.html');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadLayers();
      _tick = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (!mounted) return;
        final bt = context.read<BtViewModel>();
        _pushToWeb(bt);
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _pushToWeb(BtViewModel bt) async {
    if (!_pageReady) return;

    final LatLng? p = bt.currentPos;
    final bool receiving =
        bt.lastRxAt != null && DateTime.now().difference(bt.lastRxAt!).inSeconds <= 3;

    final String js = """
      window.updateLive(
        ${p != null ? p.latitude.toStringAsFixed(9) : "null"},
        ${p != null ? p.longitude.toStringAsFixed(9) : "null"},
        ${bt.currentAlt != null ? bt.currentAlt!.toStringAsFixed(3) : "null"},
        ${bt.currentSolution != null ? "'${bt.currentSolution}'" : "null"},
        ${receiving ? "true" : "false"}
      );
    """;

    try { await _controller.runJavaScript(js); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final bt = context.watch<BtViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Data'),
        actions: [
          IconButton(
            tooltip: 'Follow ON',
            onPressed: _pageReady ? () => _controller.runJavaScript("window.setFollowMe(true);") : null,
            icon: const Icon(Icons.location_searching),
          ),
          IconButton(
            tooltip: 'Follow OFF',
            onPressed: _pageReady ? () => _controller.runJavaScript("window.setFollowMe(false);") : null,
            icon: const Icon(Icons.location_disabled),
          ),
          PopupMenuButton<String>(
            tooltip: 'Live marker color',
            onSelected: (hex) {
              if (_pageReady) {
                _controller.runJavaScript("window.setMarkerColor('$hex');");
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: '#1976d2', child: Text('Blue')),
              PopupMenuItem(value: '#d32f2f', child: Text('Red')),
              PopupMenuItem(value: '#388e3c', child: Text('Green')),
              PopupMenuItem(value: '#f9a825', child: Text('Amber')),
            ],
            icon: const Icon(Icons.color_lens),
          ),
          IconButton(
            tooltip: 'Clear Track',
            onPressed: _pageReady ? () => _controller.runJavaScript("window.clearTrack();") : null,
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            tooltip: 'Center on live',
            onPressed: () async {
              final p = bt.currentPos;
              if (p != null && _pageReady) {
                await _controller.runJavaScript("window.centerOn(${p.latitude}, ${p.longitude}, 18);");
              }
            },
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            onPressed: vm.loading ? null : () => vm.loadLayers(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (vm.loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
