# Live check for WallhavenSource: real API -> field mapping -> full-res download.
# Mirrors WallhavenSource.parseSearch + WallpaperService.downloadToCache (Dart):
# keyless SFW search, portrait ratio, and the `path` full-res URL must fetch 200.
import json
import urllib.request

UA = {"User-Agent": "Mozilla/5.0"}
SEARCH = ("https://wallhaven.cc/api/v1/search"
          "?sorting=random&categories=111&purity=100&ratios=portrait")


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20)


data = json.loads(fetch(SEARCH).read().decode())
items = data.get("data", [])
print("wallhaven results:", len(items))
assert items, "empty Wallhaven response (API reachable?)"

checked = 0
for e in items[:5]:
    pid = e.get("id")
    path = e.get("path")
    # parseSearch contract: prefixed id, wallhaven page url, full-res path, dims
    assert pid, "missing id"
    assert str(e.get("url", "")).startswith("https://wallhaven.cc/w/"), e.get("url")
    assert isinstance(path, str) and path.startswith("https://"), path
    assert isinstance(e.get("dimension_x"), int) and isinstance(e.get("dimension_y"), int)
    assert e["dimension_y"] >= e["dimension_x"], "ratios=portrait returned a landscape item"
    r = fetch(path)
    body = r.read()
    assert r.status == 200 and body, "download failed for %s" % path
    print("  wh_%s -> %sx%s %d bytes" % (pid, e["dimension_x"], e["dimension_y"], len(body)))
    checked += 1

print("checked %d/%d items; mapping + download OK" % (checked, len(items)))
print("LIVE WALLHAVEN CHECK PASSED")
