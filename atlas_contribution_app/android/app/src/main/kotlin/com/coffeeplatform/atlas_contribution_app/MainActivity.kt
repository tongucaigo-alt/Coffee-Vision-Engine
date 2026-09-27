package com.coffeeplatform.atlas_contribution_app

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private sealed class SavedExport {
        abstract val location: String

        data class Download(val uri: Uri) : SavedExport() {
            override val location: String get() = uri.toString()
        }

        data class Legacy(val file: File) : SavedExport() {
            override val location: String get() = file.absolutePath
        }
    }

    // Diagnostic access is limited to exports successfully created by this activity.
    private val diagnosticExports = mutableMapOf<String, SavedExport>()
    private val isDiagnostic: Boolean
        get() = packageName == "com.coffeeplatform.atlas_contribution_app.diagnostic"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "atlas.contribution/export",
        ).setMethodCallHandler { call, result ->
            if (call.method == "readDiagnosticExport" || call.method == "deleteDiagnosticExport") {
                if (isDiagnostic) {
                    handleDiagnosticExport(call, result)
                } else {
                    result.notImplemented()
                }
                return@setMethodCallHandler
            }
            if (call.method != "saveToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val request = try {
                val sourcePath = requireNotNull(call.argument<String>("sourcePath"))
                val fileName = requireNotNull(call.argument<String>("fileName"))
                require(fileName.matches(Regex("^atlas-(?:katki|reviews)-[A-Za-z0-9._-]+\\.zip$")))
                val sourceCanonical = File(sourcePath).canonicalFile
                val cacheCanonical = cacheDir.canonicalFile
                require(
                    sourceCanonical.isFile &&
                        sourceCanonical.path.startsWith(cacheCanonical.path + File.separator),
                )
                sourceCanonical to fileName
            } catch (error: Exception) {
                result.error("invalid_export", "Invalid export request", null)
                return@setMethodCallHandler
            }
            val (source, fileName) = request
            val savedExport = try {
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
                        check(contentResolver.update(uri, values, null, null) > 0)
                        SavedExport.Download(uri)
                    } catch (error: Throwable) {
                        runCatching { contentResolver.delete(uri, null, null) }
                        throw error
                    }
                } else {
                    val downloads = requireNotNull(
                        getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
                    )
                    val target = File(downloads, fileName)
                    // Claim this name before writing so a failed copy can only
                    // remove the file created by this request.
                    check(target.createNewFile())
                    try {
                        source.inputStream().use { input ->
                            target.outputStream().use { output -> input.copyTo(output) }
                        }
                        SavedExport.Legacy(target.canonicalFile)
                    } catch (error: Throwable) {
                        runCatching { target.delete() }
                        throw error
                    }
                }
            } catch (error: Throwable) {
                result.error("export_failed", "Could not save export", null)
                return@setMethodCallHandler
            }
            if (isDiagnostic) diagnosticExports[savedExport.location] = savedExport
            result.success(savedExport.location)
        }
    }

    private fun handleDiagnosticExport(call: MethodCall, result: MethodChannel.Result) {
        val savedExport = try {
            val location = requireNotNull(call.argument<String>("location"))
            requireNotNull(diagnosticExports[location])
        } catch (error: Exception) {
            result.error("invalid_diagnostic_export", "Unknown diagnostic export", null)
            return
        }
        val response = try {
            if (call.method == "deleteDiagnosticExport") {
                val deleted = when (savedExport) {
                    is SavedExport.Download -> contentResolver.delete(savedExport.uri, null, null) > 0
                    is SavedExport.Legacy -> validatedDiagnosticFile(savedExport).delete()
                }
                check(deleted)
                diagnosticExports.remove(savedExport.location)
                true
            } else {
                val input = when (savedExport) {
                    is SavedExport.Download -> requireNotNull(contentResolver.openInputStream(savedExport.uri))
                    is SavedExport.Legacy -> validatedDiagnosticFile(savedExport).inputStream()
                }
                input.use { stream ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    val maxBytes = 4 * 1024 * 1024
                    while (true) {
                        val count = stream.read(buffer)
                        if (count == -1) break
                        check(count <= maxBytes - output.size())
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
            }
        } catch (error: Throwable) {
            result.error("diagnostic_export_failed", "Could not access diagnostic export", null)
            return
        }
        result.success(response)
    }

    private fun validatedDiagnosticFile(savedExport: SavedExport.Legacy): File {
        val file = savedExport.file.canonicalFile
        val downloads = requireNotNull(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)).canonicalFile
        require(file == savedExport.file && file.parentFile == downloads && file.isFile)
        return file
    }
}
