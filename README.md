# WallPin 🎲📌

Personal wallpaper roulette powered by **your own Pinterest feed** (and optional **Wallhaven**) — no official API, no server, no other users.

## Why no Pinterest API?

Pinterest API v5 requires app review and only exposes *your saved pins/boards* — not the home feed. Previous AI attempts failed because they assumed an API key could fetch the feed. It can't.

WallPin instead does what a browser does:
1. **You log in once** inside an embedded WebView (`LoginScreen`).
2. Session cookies stay in the WebView jar.
3. A headless WebView opens your home feed (or a Pinterest search for your include-keywords), scrolls, and extracts `pin → orig image` via JS.
4. Public board URLs (Settings → Extra boards) use the no-auth `widgets.pinterest.com` endpoint as a fallback.

This is fragile by nature (Pinterest changes markup), but fine for 1-user personal use. If scraping breaks, the fix is updating one JS string in `lib/services/pinterest_scraper.dart`.

## Features

- Pinterest login via WebView (password never touches app code)
- Home feed + keyword-scoped search (`include keywords`)
- Exclude-keyword + portrait-only filtering (memes/quotes dropped)
- 🎲 **Change random wallpaper** roulette button — animated (breathing gradient + spinning die), pulls from every enabled source
- **Categories**: pick vibes (Anime, Nature, Cars, Abstract, Art, Space, City, Minimal, Fantasy, Games, Sci-Fi, Flowers) — each roll picks one at random and maps it to every source's query language
- **Wallhaven source**: public JSON API, keyless by default (SFW); optional API key unlocks sketchy/NSFW, tags, categories, sorting (random/toplist/…)
- **Konachan source**: keyless Moebooru API (anime wallpapers), `order:random`, SFW mirror by default, optional tags
- **Pinterest account manager**: strict login detection + explicit log out / switch account (Settings or the login screen)
- History cache: configurable count (default 10) + retention days (default 30)
- Auto-change via native WorkManager worker (default 1/day, 1h–168h, survives reboot/app kill)
- Tap history item to restore it

## Sources

Sources are pluggable via `WallpaperSource` (`lib/services/wallpaper_source.dart`).
Each returns `PinCandidate`s; the roulette/PrefetchService pull from all enabled
sources and apply `FilterService` once.

| Source | Needs | Notes |
|---|---|---|
| `PinterestScraper` | WebView login | Headless JS scrape of feed/search + public-board pidgets fallback |
| `WallhavenSource` | network | `https://wallhaven.cc/api/v1/search`, `sorting=random`, optional API key |
| `KonachanSource` | network | `https://konachan.net/post.json` (SFW) / `konachan.com`, `order:random`, optional tags |

Enabled sources are assembled in `lib/services/source_registry.dart` from saved settings.

## Project layout

```
lib/
  main.dart                    # app entry (imports pending history, applies schedule)
  models/wallpaper_entry.dart
  services/
    pinterest_session.dart     # login state (cookies live in WebView)
    wallpaper_source.dart      # PinCandidate + WallpaperSource interface (Flutter-free)
    pinterest_scraper.dart     # headless-WebView JS extraction + board fallback
    wallhaven_source.dart      # Wallhaven JSON API source (keyless-capable)
    konachan_source.dart       # Konachan/Moebooru JSON API source (keyless)
    categories.dart            # preset categories → per-source query terms
    source_registry.dart       # builds enabled sources from settings
    filter_service.dart        # include/exclude + portrait filtering
    wallpaper_service.dart     # download (originals→thumb fallback) + MethodChannel
    history_store.dart         # cache w/ max-count + TTL pruning + pending import
    scheduler_service.dart     # foreground API for the native scheduler
    prefetch_service.dart      # refills wallpin_queue.json for the background worker
  screens/
    login_screen.dart home_screen.dart history_screen.dart settings_screen.dart
  widgets/
    roulette_button.dart       # animated gradient roulette button
android/app/src/main/...       # MainActivity.kt (wallpaper + scheduler channels),
                               # WallpaperWorker.kt (pure-native periodic auto-change)
```

## Run it (Windows)

Flutter isn't installed on this machine yet. Install once:

```powershell
winget install -e --id Google.FlutterSDK  # or choco install flutter
flutter doctor
flutter pub get   # inside D:\Downloads\wallpin
flutter run       # plug in an Android phone with USB debugging
```

Emulators can't set real wallpapers well — use a physical Android device.

## iOS note

Apple doesn't let apps change the wallpaper programmatically. The planned iOS version can only *save to Photos + notify* ("tap to set"). Android is the real target; shared Dart logic (scraper/filters/cache) is already platform-neutral for reuse.

## Roadmap (from your goals)

- [x] Wallhaven / other sources (`PinterestScraper` → `Source` interface)
- [ ] Linux/Wayland companion (separate repo — `swww`/`hyprpaper` backend)
- [ ] iOS save-to-Photos variant
