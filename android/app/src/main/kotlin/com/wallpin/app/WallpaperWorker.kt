package com.wallpin.app

import android.app.WallpaperManager
import android.content.Context
import android.graphics.BitmapFactory
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Background auto-change worker. Pure native (no Dart, no WebView) so it
 * runs reliably with the app killed, on boot, and in Doze.
 *
 * Source priority per run:
 *  1. Pop a random URL from wallpin_queue.json (refilled by the Dart
 *     PrefetchService while the app is open — this is how feed-based
 *     variety reaches the background without a WebView).
 *  2. Else fetch a random configured board via the no-auth pidgets
 *     endpoint and pick a random pin (originals first, thumb fallback).
 *  3. Else Result.retry().
 *
 * After setting the wallpaper it appends the record to
 * wallpin_pending_history.json, which Dart imports into HistoryStore on
 * next launch. Files live in cacheDir — the same dir Dart's
 * getTemporaryDirectory() maps to.
 */
class WallpaperWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val maxEntries = inputData.getInt(KEY_MAX, 10)
            val retentionDays = inputData.getInt(KEY_RETENTION, 30)

            val pick = popQueuedUrl() ?: fetchBoardPin()
                ?: return@withContext Result.retry()

            val file = download(pick.imageUrl, pick.id)
                ?: return@withContext Result.retry()

            val wm = applicationContext.getSystemService(Context.WALLPAPER_SERVICE) as WallpaperManager
            val bmp = BitmapFactory.decodeFile(file.absolutePath)
                ?: return@withContext Result.retry()
            wm.setBitmap(bmp, null, true,
                WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK)

            appendPendingHistory(pick, file)
            pruneCache(maxEntries, retentionDays)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    // ------------------------------------------------------------ queue ---

    private data class Pick(
        val id: String,
        val pageUrl: String,
        val imageUrl: String,
        val title: String?,
    )

    private fun queueFile() = File(applicationContext.cacheDir, "wallpin_queue.json")

    /** Removes and returns a random queued URL, rewriting the file. Null when empty. */
    private fun popQueuedUrl(): Pick? {
        val f = queueFile()
        if (!f.exists()) return null
        return try {
            val json = JSONObject(f.readText())
            val urls = json.optJSONArray("urls") ?: JSONArray()
            if (urls.length() == 0) return null
            val idx = (0 until urls.length()).random()
            val obj = urls.getJSONObject(idx)
            val remaining = JSONArray()
            for (i in 0 until urls.length()) {
                if (i != idx) remaining.put(urls.get(i))
            }
            json.put("urls", remaining)
            f.writeText(json.toString())
            Pick(
                id = obj.optString("id"),
                pageUrl = obj.optString("pageUrl"),
                imageUrl = obj.optString("imageUrl"),
                title = obj.optString("title").ifEmpty { null },
            ).takeIf { it.imageUrl.isNotEmpty() }
        } catch (e: Exception) {
            null
        }
    }

    // ------------------------------------------------------------ boards ---

    private fun fetchBoardPin(): Pick? {
        val boards = try {
            val json = JSONObject(queueFile().takeIf { it.exists() }?.readText() ?: return null)
            json.optJSONArray("boards") ?: return null
        } catch (e: Exception) {
            return null
        }
        if (boards.length() == 0) return null
        // Try up to 3 random boards (a board may be deleted/renamed).
        repeat(3) {
            val boardUrl = boards.getString((0 until boards.length()).random())
            val pick = fetchBoard(boardUrl)
            if (pick != null) return pick
        }
        return null
    }

    private fun fetchBoard(boardUrl: String): Pick? {
        val m = Regex("""pinterest\.com/([^/]+)/([^/?]+)""").find(boardUrl) ?: return null
        val (user, slug) = m.destructured
        val body = httpGet("https://widgets.pinterest.com/v3/pidgets/boards/$user/$slug/pins/")
            ?: return null
        return try {
            val pins = JSONObject(body).getJSONObject("data").getJSONArray("pins")
            val viable = mutableListOf<Pick>()
            for (i in 0 until pins.length()) {
                val p = pins.getJSONObject(i)
                if (p.optBoolean("is_video")) continue
                val imgs = p.optJSONObject("images") ?: continue
                val thumb = imgs.optJSONObject("564x")?.optString("url")
                    ?: imgs.optJSONObject("237x")?.optString("url")
                    ?: imgs.optJSONObject("236x")?.optString("url")
                    ?: continue
                viable.add(
                    Pick(
                        id = p.getString("id"),
                        pageUrl = "https://www.pinterest.com/pin/${p.getString("id")}/",
                        imageUrl = thumb,
                        title = p.optString("description").ifEmpty { null },
                    )
                )
            }
            if (viable.isEmpty()) null else viable.random()
        } catch (e: Exception) {
            null
        }
    }

    // ------------------------------------------------------------ download ---

    private fun originalsUpgrade(url: String): String {
        for (s in arrayOf("/736x/", "/564x/", "/474x/", "/237x/", "/236x/")) {
            if (url.contains(s)) return url.replaceFirst(s, "/originals/")
        }
        return url
    }

    /** Tries /originals/ first, falls back to the thumbnail. Null if all fail. */
    private fun download(url: String, pinId: String): File? {
        val upgraded = originalsUpgrade(url)
        val tries = if (upgraded == url) listOf(url) else listOf(upgraded, url)
        for (u in tries) {
            try {
                val bytes = httpGetBytes(u) ?: continue
                if (bytes.isEmpty()) continue
                val file = File(applicationContext.cacheDir, "wallpin_auto_$pinId.jpg")
                file.writeBytes(bytes)
                return file
            } catch (e: Exception) {
                continue
            }
        }
        return null
    }

    private fun httpGet(url: String): String? {
        val bytes = httpGetBytes(url) ?: return null
        return bytes.toString(Charsets.UTF_8)
    }

    private fun httpGetBytes(url: String): ByteArray? {
        var conn: HttpURLConnection? = null
        return try {
            conn = URL(url).openConnection() as HttpURLConnection
            conn.setRequestProperty("User-Agent", "Mozilla/5.0")
            conn.connectTimeout = 20000
            conn.readTimeout = 20000
            if (conn.responseCode != 200) return null
            conn.inputStream.use { it.readBytes() }
        } catch (e: Exception) {
            null
        } finally {
            conn?.disconnect()
        }
    }

    // ------------------------------------------------------------ handoff ---

    private fun appendPendingHistory(pick: Pick, file: File) {
        try {
            val f = File(applicationContext.cacheDir, "wallpin_pending_history.json")
            val arr = if (f.exists()) JSONArray(f.readText()) else JSONArray()
            arr.put(
                JSONObject()
                    .put("id", pick.id)
                    .put("pageUrl", pick.pageUrl)
                    .put("imageUrl", pick.imageUrl)
                    .put("title", pick.title ?: JSONObject.NULL)
                    .put("savedAt", System.currentTimeMillis())
                    .put("localPath", file.absolutePath)
            )
            // Atomic write: temp + rename, so Dart never reads a half-file.
            val tmp = File(applicationContext.cacheDir, "wallpin_pending_history.json.tmp")
            tmp.writeText(arr.toString())
            tmp.renameTo(f)
        } catch (e: Exception) {
            // History handoff is best-effort; wallpaper is already set.
        }
    }

    private fun pruneCache(maxEntries: Int, retentionDays: Int) {
        try {
            val cutoff = System.currentTimeMillis() - retentionDays * 24L * 3600L * 1000L
            val files = applicationContext.cacheDir
                .listFiles { f -> f.name.startsWith("wallpin_auto_") }
                ?.sortedBy { it.lastModified() } ?: return
            for (f in files) {
                if (f.lastModified() < cutoff) f.delete()
            }
            val remaining = files.filter { it.exists() }.sortedBy { it.lastModified() }
            if (remaining.size > maxEntries) {
                for (f in remaining.take(remaining.size - maxEntries)) f.delete()
            }
        } catch (e: Exception) {
        }
    }

    companion object {
        const val KEY_MAX = "maxEntries"
        const val KEY_RETENTION = "retentionDays"
    }
}
