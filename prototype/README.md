# WallPin DOM-extraction prototype (throwaway harness, not shipped in the app)

Proves the Pinterest scraping strategy works without an official API.

- `extractor.js` — MUST stay identical to `PinterestScraper._extractJs`
  in `lib/services/pinterest_scraper.dart`. If you change one, change both.
- `sample_feed.html` — mocked feed covering: classic pin, srcset pin, meme,
  duplicate links (dedupe), video pin (skip), non-pin link (ignore),
  already-originals URL.
- `run.js` — loads the HTML in jsdom, runs the real extractor JS, applies a
  FilterService-equivalent, asserts everything. Run: `node run.js`
- `live_board_check.py` — hits the real no-auth pidgets endpoint for a public
  board and verifies the downloader chain (originals → thumbnail fallback).
  Run: `python live_board_check.py`
- `wallhaven_check.py` — hits the live Wallhaven search API (keyless, SFW,
  portrait) and verifies the `WallhavenSource.parseSearch` field mapping plus a
  full-res `path` download. Run: `python wallhaven_check.py`
- `konachan_check.py` — hits the live Konachan Moebooru API (keyless, SFW,
  random) and verifies the `KonachanSource.parsePosts` field mapping plus a
  full-res `file_url` download. Run: `python konachan_check.py`

Live findings baked into the app (2026-10-07):
1. Pidgets image keys are `236x`/`237x`/`564x` — there is NO `orig` key.
2. Full-res prefix is `/originals/` (`/orig/` → HTTP 403).
3. `/originals/` 403s for a minority of pins → downloader falls back to thumb.
4. Pinterest SSR HTML contains no `/pin/` links → feed scraping genuinely
   needs the JS-rendered WebView, SSR scraping alone can't work.
