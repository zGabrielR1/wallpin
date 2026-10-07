package com.wallpin.app

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val wallpaperChannel = "wallpin/wallpaper"
    private val schedulerChannel = "wallpin/scheduler"

    companion object {
        const val AUTO_WORK_NAME = "wallpin.autoChange"
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, wallpaperChannel).setMethodCallHandler { call, result ->
            if (call.method == "setWallpaper") {
                val path = call.argument<String>("path")
                val location = call.argument<Int>("location") ?: 2
                if (path == null) {
                    result.error("ARG", "Missing path", null)
                    return@setMethodCallHandler
                }
                try {
                    val wm = WallpaperManager.getInstance(this)
                    val bmp = BitmapFactory.decodeFile(path)
                        ?: throw IllegalArgumentException("Cannot decode image: $path")
                    val which = when (location) {
                        0 -> WallpaperManager.FLAG_SYSTEM
                        1 -> WallpaperManager.FLAG_LOCK
                        else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        wm.setBitmap(bmp, null, true, which)
                    } else {
                        @Suppress("DEPRECATION")
                        wm.setBitmap(bmp)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("WALLPAPER", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, schedulerChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    // WorkManager minimum interval is 15 min; our UI min is 1h.
                    val hours = (call.argument<Int>("hours") ?: 24).coerceIn(1, 24 * 30)
                    val data = workDataOf(
                        WallpaperWorker.KEY_MAX to (call.argument<Int>("maxEntries") ?: 10),
                        WallpaperWorker.KEY_RETENTION to (call.argument<Int>("retentionDays") ?: 30),
                    )
                    val request = PeriodicWorkRequestBuilder<WallpaperWorker>(hours.toLong(), TimeUnit.HOURS)
                        .setConstraints(
                            Constraints.Builder()
                                .setRequiredNetworkType(NetworkType.CONNECTED)
                                .build()
                        )
                        .setInputData(data)
                        .build()
                    WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                        AUTO_WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request
                    )
                    result.success(true)
                }
                "cancel" -> {
                    WorkManager.getInstance(this).cancelUniqueWork(AUTO_WORK_NAME)
                    result.success(true)
                }
                "runNow" -> {
                    // One-off change now (used by a "change now in background" path
                    // and manual testing); same worker, no constraints beyond network.
                    val data = workDataOf(
                        WallpaperWorker.KEY_MAX to (call.argument<Int>("maxEntries") ?: 10),
                        WallpaperWorker.KEY_RETENTION to (call.argument<Int>("retentionDays") ?: 30),
                    )
                    val request = OneTimeWorkRequestBuilder<WallpaperWorker>()
                        .setConstraints(
                            Constraints.Builder()
                                .setRequiredNetworkType(NetworkType.CONNECTED)
                                .build()
                        )
                        .setInputData(data)
                        .build()
                    WorkManager.getInstance(this)
                        .enqueueUniqueWork("$AUTO_WORK_NAME.once", ExistingWorkPolicy.REPLACE, request)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
