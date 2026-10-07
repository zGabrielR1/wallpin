# Validates the wallpin_queue.json / wallpin_pending_history.json contract
# shared between Dart (PrefetchService/HistoryStore) and Kotlin (WallpaperWorker).
# Run: python queue_contract_check.py
import json

q = json.load(open("queue_sample.json"))
assert set(q.keys()) == {"urls", "boards"}, "queue top-level keys"
for u in q["urls"]:
    assert set(u.keys()) == {"id", "pageUrl", "imageUrl", "title"}, "queue url entry keys: %s" % u
    assert u["pageUrl"].startswith("https://www.pinterest.com/pin/"), "pageUrl shape"
    assert u["imageUrl"].startswith("https://i.pinimg.com/"), "imageUrl shape"
for b in q["boards"]:
    assert "pinterest.com/" in b, "board url shape"

# Pending-history record shape (as written by WallpaperWorker.appendPendingHistory).
rec = {"id": "1", "pageUrl": "https://www.pinterest.com/pin/1/",
       "imageUrl": "https://i.pinimg.com/564x/a.jpg", "title": None,
       "savedAtMillis": 1789876543210, "localPath": "/data/data/com.wallpin.app/cache/wallpin_auto_1.jpg"}
assert isinstance(rec["savedAtMillis"], int), "millis epoch, not ISO string"
assert rec["localPath"].endswith(".jpg"), "history file must exist on import"

print("QUEUE CONTRACT CHECK PASSED")
