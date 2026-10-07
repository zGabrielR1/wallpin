import 'dart:io';

import 'package:flutter/material.dart';

import '../services/history_store.dart';
import '../services/wallpaper_service.dart';

class HistoryScreen extends StatefulWidget {
  final HistoryStore history;
  const HistoryScreen({super.key, required this.history});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<void> _reapply(String path) async {
    try {
      await WallpaperService().setWallpaper(File(path));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallpaper restored.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.history.entries;
    return Scaffold(
      appBar: AppBar(title: Text('Recent wallpapers (${entries.length})')),
      body: entries.isEmpty
          ? const Center(child: Text('No cached wallpapers yet — roll the dice on the home screen!'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final e = entries[i];
                final exists = File(e.localPath).existsSync();
                return GestureDetector(
                  onTap: exists ? () => _reapply(e.localPath) : null,
                  child: GridTile(
                    footer: GridTileBar(backgroundColor: Colors.black54, title: Text(e.title ?? e.id, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    child: exists ? Image.file(File(e.localPath), fit: BoxFit.cover) : const Icon(Icons.broken_image),
                  ),
                );
              },
            ),
    );
  }
}
