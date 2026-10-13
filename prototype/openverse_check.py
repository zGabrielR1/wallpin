# Live check for OpenverseSource: real API -> field mapping -> download.
# Mirrors OpenverseSource.parseResults + WallpaperService.downloadToCache (Dart):
# keyless, aspect_ratio=tall + size=large, direct `url` must fetch 200.
import json
import urllib.request

UA = {"User-Agent": "WallPin/0.1 (personal wallpaper roulette)"}
SEARCH = ("https://api.openverse.org/v1/images/"
          "?q=nature%20landscape&aspect_ratio=tall&size=large&page_size=3")


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30)


data = json.loads(fetch(SEARCH).read().decode())
items = data.get("results", [])
print("openverse results:", len(items))
assert items, "empty Openverse response"

checked = 0
for e in items:
    pid = e.get("id")
    url = e.get("url")
    # parseResults contract: prefixed id, direct image url, numeric dimensions
    assert pid, "missing id"
    assert isinstance(url, str) and url.startswith("https://"), url
    assert isinstance(e.get("width"), int) and isinstance(e.get("height"), int)
    assert e["height"] > e["width"], "aspect_ratio=tall returned a landscape item"
    r = fetch(url)
    body = r.read()
    assert r.status == 200 and body, "download failed for %s" % url
    print("  ov_%s -> %sx%s %d bytes" % (pid, e["width"], e["height"], len(body)))
    checked += 1

print("checked %d items; mapping + download OK" % checked)
print("LIVE OPENVERSE CHECK PASSED")
