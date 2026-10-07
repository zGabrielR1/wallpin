# End-to-end: real board -> pidgets -> downloader chain (originals, else thumb).
# Mirrors WallpaperService.downloadToCache (Dart) step for step.
import json
import urllib.request

UA = {"User-Agent": "Mozilla/5.0"}
SIZES = ("/736x/", "/564x/", "/474x/", "/237x/", "/236x/")


def upgrade(url):
    for s in SIZES:
        if s in url:
            return url.replace(s, "/originals/", 1)
    return url


def download(url):
    """Returns (bytes, which) trying originals first, then the thumbnail."""
    upgraded = upgrade(url)
    tries = [upgraded] if upgraded == url else [upgraded, url]
    for u in tries:
        try:
            r = urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=20)
            body = r.read()
            if r.status == 200 and body:
                return body, ("originals" if u == upgraded and upgraded != url else "thumb")
        except Exception:
            continue
    return None, "FAILED"


req = urllib.request.Request(
    "https://widgets.pinterest.com/v3/pidgets/boards/pinterest/girls-night-in/pins/",
    headers=UA,
)
pins = json.loads(urllib.request.urlopen(req, timeout=20).read().decode())["data"]["pins"]
print("pins from API:", len(pins))

ok = skipped = failed = via_originals = via_thumb = 0
for p in pins[:12]:
    if p.get("is_video"):
        skipped += 1
        continue
    imgs = p["images"]
    thumb = (imgs.get("564x") or imgs.get("237x") or imgs.get("236x"))["url"]
    body, which = download(thumb)
    if body is None:
        failed += 1
        print("  %s -> FAILED all candidates" % p["id"])
    else:
        ok += 1
        if which == "originals":
            via_originals += 1
        else:
            via_thumb += 1
        print("  %s -> 200 %d bytes via %s" % (p["id"], len(body), which))

print("ok=%d (originals=%d thumb-fallback=%d) skipped=%d failed=%d"
      % (ok, via_originals, via_thumb, skipped, failed))
assert failed == 0, "downloader chain failed for some pins"
print("LIVE BOARD CHECK PASSED")
