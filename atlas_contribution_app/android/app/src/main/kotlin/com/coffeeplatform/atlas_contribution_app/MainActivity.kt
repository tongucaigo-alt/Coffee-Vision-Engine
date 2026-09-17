package com.coffeeplatform.atlas_contribution_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "atlas.contribution/export",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val sourcePath = call.argument<String>("sourcePath")
            val fileName = call.argument<String>("fileName")
            if (sourcePath == null ||
                fileName == null ||
                !fileName.matches(Regex("^atlas-katki-[A-Za-z0-9._-]+\\.zip$"))
            ) {
                result.error("invalid_export", "Invalid export request", null)
                return@setMethodCallHandler
            }
            val source = File(sourcePath)
            val sourceCanonical = source.canonicalFile
            val cacheCanonical = cacheDir.canonicalFile
            if (!sourceCanonical.isFile ||
                !sourceCanonical.path.startsWith(cacheCanonical.path + File.separator)
            ) {
                result.error("invalid_export", "Export source is not app-owned", null)
                return@setMethodCallHandler
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                        put(MediaStore.Downloads.MIME_TYPE, "application/zip")
                        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        values,
                    ) ?: error("Could not create download")
                    try {
                        contentResolver.openOutputStream(uri, "w").use { output ->
                            requireNotNull(output)
                            source.inputStream().use { it.copyTo(output) }
                        }
                        values.clear()
                        values.put(MediaStore.Downloads.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                        result.success(uri.toString())
                    } catch (error: Throwable) {
                        contentResolver.delete(uri, null, null)
                        throw error
                    }
                } else {
                    val downloads = requireNotNull(
                        getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
                    )
                    val target = File(downloads, fileName)
                    source.copyTo(target, overwrite = false)
                    result.success(target.absolutePath)
                }
            } catch (error: Throwable) {
                result.error("export_failed", "Could not save export", null)
            }
        }
    }
}
