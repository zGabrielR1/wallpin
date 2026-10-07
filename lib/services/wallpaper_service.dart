import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Sets the Android wallpaper via a tiny platform channel.
///
/// Native side: `MainActivity.kt` implements `wallpin/wallpaper` →
/// `setWallpaper(path, location)` using `WallpaperManager`.
/// `location`: 0 = home, 1 = lock, 2 = both.
class WallpaperService {
  static const _channel = MethodChannel('wallpin/wallpaper');

  static const _thumbSizes = ['/736x/', '/564x/', '/474x/', '/237x/', '/236x/'];

  /// `https://i.pinimg.com/564x/a/b.jpg` → `.../originals/a/b.jpg`, or the
  /// input unchanged when it has no thumbnail-size segment.
  static String upgradeToOriginal(String url) {
    for (final s in _thumbSizes) {
      if (url.contains(s)) return url.replaceFirst(s, '/originals/');
    }
    return url;
  }

  /// Downloads the best available resolution: tries the `/originals/`
  /// upgrade first, falls back to the thumbnail URL on any failure.
  /// (Live-tested: '/originals/' 403s for a minority of pins whose original
  /// was never stored under the same hash path.)
  Future<File> downloadToCache(String url, String pinId) async {
    final upgraded = upgradeToOriginal(url);
    final tries = upgraded == url ? [url] : [upgraded, url];
    Exception? lastError;
    for (final u in tries) {
      try {
        final resp = await http.get(Uri.parse(u));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/wallpin_$pinId.jpg');
          await file.writeAsBytes(resp.bodyBytes);
          return file;
        }
        lastError = Exception('Download failed: HTTP ${resp.statusCode} for $u');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('Download failed for $url');
  }

  Future<void> setWallpaper(File file, {int location = 2}) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Setting wallpaper is only supported on Android. '
          'iOS does not allow apps to change the wallpaper programmatically — '
          'on iOS the app can only save to Photos so you can set it manually.');
    }
    await _channel.invokeMethod('setWallpaper', {'path': file.path, 'location': location});
  }
}
