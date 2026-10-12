# Live check for KonachanSource: real Moebooru API -> field mapping -> download.
# Mirrors KonachanSource.parsePosts + WallpaperService.downloadToCache (Dart):
# keyless SFW (rating:safe), random ordering, full-res file_url must fetch 200.
import json
import urllib.request

UA = {"User-Agent": "WallPin/0.1 (personal wallpaper roulette)"}
SEARCH = "https://konachan.net/post.json?tags=rating:safe+order:random&limit=5"


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30)


items = json.loads(fetch(SEARCH).read().decode())
print("konachan results:", len(items))
assert items, "empty Konachan response"

checked = 0
for e in items:
    pid = e.get("id")
    url = e.get("file_url") or e.get("jpeg_url") or e.get("sample_url")
    # parsePosts contract: prefixed id, full-res url, numeric dimensions
    assert pid, "missing id"
    assert isinstance(url, str) and url.startswith("https://"), url
    assert isinstance(e.get("width"), int) and isinstance(e.get("height"), int)
    assert e.get("rating") == "s", e.get("rating")
    r = fetch(url)
    body = r.read()
    assert r.status == 200 and body, "download failed for %s" % url
    print("  kc_%s -> %sx%s %d bytes" % (pid, e["width"], e["height"], len(body)))
    checked += 1

print("checked %d items; mapping + download OK" % checked)
print("LIVE KONACHAN CHECK PASSED")
