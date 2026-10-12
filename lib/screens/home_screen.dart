import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallpaper_entry.dart';
import '../services/categories.dart';
import '../services/filter_service.dart';
import '../services/history_store.dart';
import '../services/pinterest_session.dart';
import '../services/prefetch_service.dart';
import '../services/source_registry.dart';
import '../services/wallpaper_service.dart';
import '../services/wallpaper_source.dart';
import '../widgets/roulette_button.dart';

/// Main screen: current wallpaper + big "roulette" button.
class HomeScreen extends StatefulWidget {
  final PinterestSession session;
  final HistoryStore history;
  const HomeScreen({super.key, required this.session, required this.history});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _status;
  HeadlessInAppWebView? _headless;
  late final WallpaperService _wallpapers = WallpaperService();

  @override
  void initState() {
    super.initState();
    _headless = HeadlessInAppWebView(initialUrlRequest: URLRequest(url: WebUri('https://www.pinterest.com/')));
    _headless?.run();
    // Pick up anything the native worker changed while we were away, and
    // make sure the background queue isn't empty (fire-and-forget).
    widget.history.importPending().then((n) {
      if (n > 0 && mounted) setState(() {});
    });
    SharedPreferences.getInstance().then((_) {
      // ignore: discarded_futures
      PrefetchService.topUp(headless: _headless);
    });
  }

  @override
  void dispose() {
    _headless?.dispose();
    super.dispose();
  }

  Future<void> _roulette() async {
    setState(() {
      _busy = true;
      _status = 'Rolling across your sources…';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final category = randomCategory(prefs);
      final sources = buildSources(prefs, headless: _headless, category: category);
      if (category != null) setState(() => _status = 'Rolling in “${category.name}”…');

      // Pull from every source; one failing (e.g. logged-out Pinterest) must
      // not sink the roll, so errors are collected and only reported if we
      // end up with nothing.
      final raw = <PinCandidate>[];
      final errors = <String>[];
      for (final s in sources) {
        try {
          raw.addAll(await s.fetch());
        } catch (e) {
          errors.add('${s.name}: $e');
        }
      }
      final candidates = FilterService(prefs).apply(raw);
      if (candidates.isEmpty) {
        final detail = errors.isEmpty ? '' : ' (${errors.join('; ')})';
        setState(() => _status = 'No wallpapers found. Try adding include keywords in Settings, or scroll your feed once in the login view.$detail');
        return;
      }
      final pick = candidates[Random().nextInt(candidates.length)];
      setState(() => _status = 'Setting "${(pick.title ?? pick.pinId).toString().substring(0, (pick.title ?? pick.pinId).length.clamp(0, 60))}"…');

      final temp = await _wallpapers.downloadToCache(pick.imageUrl, pick.pinId);
      final file = await widget.history.persistTempFile(temp, pick.pinId);
      await _wallpapers.setWallpaper(file);
      await widget.history.add(WallpaperEntry(
        id: pick.pinId,
        pageUrl: pick.pageUrl,
        imageUrl: pick.imageUrl,
        title: pick.title,
        savedAt: DateTime.now(),
        localPath: file.path,
      ));
      setState(() => _status = 'Wallpaper set! 🎲 Roll again or check History.');
      // Refill the background worker's queue with the fresh candidates
      // (fire-and-forget — the wallpaper is already set).
      // ignore: discarded_futures
      PrefetchService.topUp(headless: _headless);
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = widget.history.entries.isEmpty ? null : widget.history.entries.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WallPin 🎲'),
        actions: [
          IconButton(icon: const Icon(Icons.history), tooltip: 'History', onPressed: () => Navigator.pushNamed(context, '/history')),
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Settings', onPressed: () => Navigator.pushNamed(context, '/settings')),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (latest != null && File(latest.localPath).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(latest.localPath), height: 320, fit: BoxFit.cover),
                )
              else
                const Icon(Icons.wallpaper, size: 96),
              const SizedBox(height: 16),
              if (latest?.title != null) Text(latest!.title!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (_status != null) Text(_status!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              RouletteButton(onPressed: _busy ? null : _roulette, busy: _busy),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/history'),
                child: Text('History (${widget.history.entries.length} cached)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
