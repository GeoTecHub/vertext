import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../bluetooth/bt_viewmodel.dart';

class SdCardView extends StatefulWidget {
  const SdCardView({super.key});
  @override
  State<SdCardView> createState() => _SdCardViewState();
}

class _SdCardViewState extends State<SdCardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bt = context.read<BtViewModel>();
      if (bt.connected) bt.requestSdInfo();
    });
  }

  Future<void> _refreshAll(BtViewModel bt) async {
    bt.requestSdInfo();
    await Future.delayed(const Duration(milliseconds: 500));
    bt.requestSdList();
  }

  Future<void> _downloadAndShare(BtViewModel bt, String filename) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $filename...')),
    );
    bt.downloadFile(filename, onComplete: (name, content) async {
      try {
        final dir  = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsString(content);
        if (mounted) {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], text: 'VerText GNSS: $name'),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save error: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BtViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SD Card'),
        backgroundColor: const Color(0xFF222222),
        foregroundColor: Colors.white,
        actions: [
          if (bt.connected)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _refreshAll(bt),
            ),
        ],
      ),
      body: bt.connected
          ? _buildContent(bt)
          : const Center(child: Text('Connect to a device first.')),
    );
  }

  Widget _buildContent(BtViewModel bt) {
    return Column(
      children: [
        // ── SD Card Summary Card ──────────────────────────────────────────────
        _SdSummaryCard(bt: bt),
        const Divider(height: 1),
        // ── File list header ─────────────────────────────────────────────────
        Container(
          color: Colors.blue[50],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Files on SD Card',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A))),
              ),
              TextButton.icon(
                onPressed: bt.sdListLoading
                    ? null
                    : () => bt.requestSdList(),
                icon: bt.sdListLoading
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.list, size: 18),
                label: const Text('List Files'),
              ),
            ],
          ),
        ),
        // ── File list ────────────────────────────────────────────────────────
        Expanded(
          child: bt.sdFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(bt.sdListLoading
                          ? 'Loading files...'
                          : 'Tap "List Files" to browse SD card',
                        style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: bt.sdFiles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final f = bt.sdFiles[i];
                    return ListTile(
                      leading: Icon(
                        f.name.toLowerCase().endsWith('.nmea')
                            ? Icons.gps_fixed
                            : Icons.insert_drive_file,
                        color: const Color(0xFF1E3A8A),
                      ),
                      title: Text(f.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${f.sizeKb.toStringAsFixed(1)} KB'),
                      trailing: bt.isDownloadingFile && bt.downloadFilename == f.name
                          ? const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(Icons.download_outlined,
                                  color: Color(0xFF1E3A8A)),
                              tooltip: 'Download & Share',
                              onPressed: () => _downloadAndShare(bt, f.name),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SdSummaryCard extends StatelessWidget {
  const _SdSummaryCard({required this.bt});
  final BtViewModel bt;

  @override
  Widget build(BuildContext context) {
    final totalMb = bt.sdTotalMb;
    final freeMb  = bt.sdFreeMb;
    final usedMb  = totalMb - freeMb;
    final usedPct = totalMb > 0 ? usedMb / totalMb : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sd_card, color: Color(0xFF1E3A8A), size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    totalMb > 0
                        ? '${totalMb.toStringAsFixed(0)} MB total'
                        : 'No SD card detected',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (totalMb > 0)
                    Text(
                      '${freeMb.toStringAsFixed(0)} MB free  •  '
                      '${bt.sdFileCount} file${bt.sdFileCount != 1 ? "s" : ""}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                tooltip: 'Refresh SD info',
                onPressed: bt.requestSdInfo,
              ),
            ],
          ),
          if (totalMb > 0) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: usedPct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              color: usedPct > 0.9 ? Colors.red : const Color(0xFF1E3A8A),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${(usedPct * 100).toStringAsFixed(1)}% used  '
              '(${usedMb.toStringAsFixed(0)} MB / ${totalMb.toStringAsFixed(0)} MB)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
