import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallpaper_entry.dart';
import '../services/filter_service.dart';
import '../services/history_store.dart';
import '../services/pinterest_scraper.dart';
import '../services/pinterest_session.dart';
import '../services/prefetch_service.dart';
import '../services/wallpaper_service.dart';

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
    SharedPreferences.getInstance().then((prefs) {
      // ignore: discarded_futures
      PrefetchService.topUp(PinterestScraper(FilterService(prefs)), headless: _headless);
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
      _status = 'Reading your Pinterest feed…';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final scraper = PinterestScraper(FilterService(prefs));

      // Also mix in explicit public boards configured in Settings.
      final boardsRaw = prefs.getString('extra_boards') ?? '';
      final boardUrls = boardsRaw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      var candidates = await scraper.fetchCandidates(headlessWebView: _headless);
      for (final b in boardUrls.take(3)) {
        candidates.addAll(await scraper.fetchBoardPins(b));
      }
      if (candidates.isEmpty) {
        setState(() => _status = 'No wallpapers found. Try adding include keywords in Settings, or scroll your feed once in the login view.');
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
      PrefetchService.topUp(scraper, headless: _headless);
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
              FilledButton.icon(
                onPressed: _busy ? null : _roulette,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.casino),
                label: Text(_busy ? 'Rolling…' : 'Change random wallpaper'),
              ),
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
