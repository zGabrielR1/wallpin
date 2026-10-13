# Live check for SafebooruSource: real booru API -> field mapping -> download.
# Mirrors SafebooruSource.parsePosts + WallpaperService.downloadToCache (Dart):
# keyless, SFW-only, sort:random, full-res file_url must fetch 200.
import json
import urllib.request

UA = {"User-Agent": "WallPin/0.1 (personal wallpaper roulette)"}
SEARCH = ("https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1"
          "&limit=5&tags=sort:random")


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30)


items = json.loads(fetch(SEARCH).read().decode())
print("safebooru results:", len(items))
assert items, "empty Safebooru response"

checked = 0
for e in items:
    pid = e.get("id")
    url = e.get("file_url")
    # parsePosts contract: prefixed id, full-res url, numeric dimensions
    assert pid, "missing id"
    assert isinstance(url, str) and url.startswith("https://"), url
    assert isinstance(e.get("width"), int) and isinstance(e.get("height"), int)
    assert e.get("rating") == "safe", e.get("rating")
    r = fetch(url)
    body = r.read()
    assert r.status == 200 and body, "download failed for %s" % url
    print("  sb_%s -> %sx%s %d bytes" % (pid, e["width"], e["height"], len(body)))
    checked += 1

print("checked %d items; mapping + download OK" % checked)
print("LIVE SAFEBOORU CHECK PASSED")
