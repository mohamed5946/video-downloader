package com.valor.snapdl

import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Native bridge for SnapDL.
 *
 * Engine: youtubedl-android 0.18.1 (Maven Central:
 * io.github.junkfood02.youtubedl-android) — the same CPython 3.11 + yt-dlp
 * bundle Seal / YTDLnis use. The official yt-dlp Linux aarch64 binary is
 * dynamically linked against glibc and cannot run on Android, which is why
 * the app uses this library instead of a raw binary.
 *
 * ffmpeg comes from the matching
 * io.github.junkfood02.youtubedl-android:ffmpeg artifact.
 */
class MainActivity : FlutterActivity() {

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var engineReady = false
    private var ffmpegDir: String? = null
    private var adblockChannel: MethodChannel? = null
    private var vpnConsentIntent: Intent? = null

    companion object {
        private const val VPN_REQUEST_CODE = 9001
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                startAdBlockService()
                adblockChannel?.invokeMethod(
                    "vpnConsentResult", mapOf("granted" to true)
                )
            } else {
                adblockChannel?.invokeMethod(
                    "vpnConsentResult", mapOf("granted" to false)
                )
            }
        }
    }

    private fun startAdBlockService() {
        val intent = Intent(this, AdBlockVpnService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        adblockChannel = MethodChannel(messenger, "com.valor.snapdl/adblock")
        adblockChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isRunning" -> result.success(AdBlockVpnService.isRunning)
                "blockedCount" -> result.success(AdBlockVpnService.blockedCount.get())
                "prepare" -> {
                    val intent = VpnService.prepare(this)
                    if (intent == null) {
                        result.success(mapOf("needsConsent" to false))
                    } else {
                        vpnConsentIntent = intent
                        result.success(mapOf("needsConsent" to true))
                    }
                }
                "launchConsent" -> {
                    val intent = vpnConsentIntent
                    if (intent != null) {
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "start" -> {
                    startAdBlockService()
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, AdBlockVpnService::class.java))
                    result.success(true)
                }
                "updateBlocklist" -> {
                    Thread { updateBlocklist(result) }.start()
                }
                "openSystemSettings" -> {
                    try {
                        startActivity(
                            Intent(android.provider.Settings.ACTION_SETTINGS)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "com.valor.snapdl/engine_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(messenger, "com.valor.snapdl/engine")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> initEngine(result)
                    "fetchFormats" -> {
                        val url = call.argument<String>("url") ?: ""
                        Thread { fetchFormats(url, result) }.start()
                    }
                    "startDownload", "resumeDownload" -> {
                        val id = call.argument<String>("id") ?: ""
                        val url = call.argument<String>("url") ?: ""
                        val formatId = call.argument<String>("formatId") ?: "best"
                        val audioOnly = call.argument<Boolean>("audioOnly") ?: false
                        Thread { runDownload(id, url, formatId, audioOnly, result) }.start()
                    }
                    "pauseDownload" -> {
                        val id = call.argument<String>("id") ?: ""
                        val stopped = try {
                            YoutubeDL.destroyProcessById(id)
                        } catch (e: Exception) {
                            false
                        }
                        result.success(stopped)
                    }
                    "cancelDownload" -> {
                        val id = call.argument<String>("id") ?: ""
                        try {
                            YoutubeDL.destroyProcessById(id)
                        } catch (e: Exception) {
                            // Already finished / never started.
                        }
                        result.success(true)
                    }
                    "downloadDir" -> result.success(downloadDir().absolutePath)
                    "openFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        result.success(openFile(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ---------------------------------------------------------------- engine

    private fun initEngine(result: MethodChannel.Result) {
        if (engineReady) {
            // v1.0.1: even the cached path must never throw off the main thread.
            try {
                result.success(YoutubeDL.version(applicationContext) ?: "")
            } catch (t: Throwable) {
                result.error("ENGINE_INIT", t.message, null)
            }
            return
        }
        Thread {
            try {
                YoutubeDL.init(applicationContext)
                FFmpeg.init(applicationContext)
                // v1.0.1: a failure locating ffmpeg must not fail the engine.
                ffmpegDir = try {
                    findFfmpegDir()
                } catch (t: Throwable) {
                    null
                }
                engineReady = true
                val version = try {
                    YoutubeDL.version(applicationContext) ?: ""
                } catch (t: Throwable) {
                    ""
                }
                mainHandler.post { result.success(version) }
            } catch (t: Throwable) {
                // v1.0.1: catch Throwable (incl. UnsatisfiedLinkError and
                // other Errors) — an uncaught Error on this worker thread
                // kills the whole app process ("has stopped" on launch).
                // Always answer the Dart side so it never hangs.
                mainHandler.post {
                    result.error("ENGINE_INIT", t.message, null)
                }
            }
        }.start()
    }

    /** Locate the extracted ffmpeg executable so yt-dlp can merge / convert. */
    private fun findFfmpegDir(): String? {
        // v1.0.1: never let a filesystem walk throw into the engine init.
        return try {
            val roots = listOf(
                File(noBackupFilesDir, "youtubedl-android/packages/ffmpeg"),
                File(filesDir, "youtubedl-android/packages/ffmpeg"),
                File(applicationContext.noBackupFilesDir, "youtubedl-android")
            )
            for (root in roots) {
                if (!root.exists()) continue
                val found = root.walkTopDown()
                    .filter { it.isFile }
                    .firstOrNull {
                        it.name == "ffmpeg" || it.name.startsWith("libffmpeg")
                    }
                if (found != null) {
                    found.setExecutable(true)
                    return found.parentFile?.absolutePath
                }
            }
            null
        } catch (t: Throwable) {
            null
        }
    }

    private fun downloadDir(): File {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            ),
            "SnapDL"
        )
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    // -------------------------------------------------------------- formats

    private fun fetchFormats(url: String, result: MethodChannel.Result) {
        try {
            val request = YoutubeDLRequest(url)
            request.addOption("-J")
            request.addOption("--no-playlist")
            request.addOption("--no-warnings")
            val response = YoutubeDL.execute(request)
            if (response.out.isBlank()) {
                throw Exception("yt-dlp returned no data. ${response.err}")
            }
            mainHandler.post { result.success(response.out) }
        } catch (e: Exception) {
            mainHandler.post { result.error("FORMATS", e.message, null) }
        }
    }

    // ------------------------------------------------------------- download

    private fun runDownload(
        id: String,
        url: String,
        formatId: String,
        audioOnly: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            val request = YoutubeDLRequest(url)
            if (audioOnly) {
                request.addOption("-x")
                request.addOption("--audio-format", "mp3")
                request.addOption("-f", "bestaudio/best")
            } else {
                request.addOption("-f", formatId)
            }
            request.addOption("--newline")
            request.addOption("--continue")
            request.addOption("--no-playlist")
            request.addOption("--no-warnings")
            ffmpegDir?.let { request.addOption("--ffmpeg-location", it) }
            request.addOption(
                "-o",
                downloadDir().absolutePath + "/%(title)s.%(ext)s"
            )
            val response = YoutubeDL.execute(
                request,
                processId = id,
                callback = { progress, eta, line ->
                    postProgress(id, progress, eta, line)
                }
            )
            val filePath = findOutputFile(response.out)
            val size = filePath?.let { File(it).let { f -> if (f.exists()) f.length() else 0L } } ?: 0L
            postEvent(mapOf(
                "id" to id,
                "status" to "done",
                "filePath" to (filePath ?: ""),
                "fileSizeBytes" to size
            ))
            mainHandler.post { result.success(true) }
        } catch (e: YoutubeDL.CanceledException) {
            // Paused or cancelled by the user — Dart already updated the UI.
            postEvent(mapOf("id" to id, "status" to "cancelled"))
            mainHandler.post { result.success(false) }
        } catch (e: Exception) {
            postEvent(mapOf(
                "id" to id,
                "status" to "error",
                "error" to (e.message ?: "Download failed")
            ))
            mainHandler.post { result.success(false) }
        }
    }

    private fun postProgress(id: String, progress: Float, eta: Long, line: String) {
        val speed = Regex("""(\d+(?:\.\d+)?\s*(?:KiB|MiB|GiB)/s)""")
            .find(line)?.groupValues?.getOrNull(1) ?: ""
        postEvent(mapOf(
            "id" to id,
            "status" to "progress",
            "progress" to progress.toDouble(),
            "etaSeconds" to eta,
            "speed" to speed
        ))
    }

    private fun postEvent(event: Map<String, Any>) {
        mainHandler.post { eventSink?.success(event) }
    }

    /** Parse the final output file from yt-dlp's log lines. */
    private fun findOutputFile(out: String): String? {
        val dest = Regex("""\[download\] Destination: (.+)""")
            .find(out)?.groupValues?.getOrNull(1)?.trim()
        if (dest != null) return dest
        val merged = Regex("""\[Merger\] Merging formats into "(.+)"""")
            .find(out)?.groupValues?.getOrNull(1)?.trim()
        if (merged != null) return merged
        val audio = Regex("""\[ExtractAudio\] Destination: (.+)""")
            .find(out)?.groupValues?.getOrNull(1)?.trim()
        if (audio != null) return audio
        // Fallback: newest file in the download folder.
        return downloadDir().listFiles()
            ?.filter { it.isFile && !it.name.endsWith(".part") }
            ?.maxByOrNull { it.lastModified() }
            ?.absolutePath
    }

    // ---------------------------------------------------------------- files

    // ------------------------------------------------------------ ad blocker

    /** Download the latest StevenBlack hosts file into app storage;
     *  the VPN service prefers this file over the bundled copy. */
    private fun updateBlocklist(result: MethodChannel.Result) {
        try {
            val url = URL(
                "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
            )
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.readTimeout = 30000
            conn.connect()
            if (conn.responseCode != 200) {
                mainHandler.post {
                    result.error("BLOCKLIST", "HTTP ${conn.responseCode}", null)
                }
                return
            }
            val outFile = File(filesDir, "adblock-hosts.txt")
            conn.inputStream.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            }
            val ok = outFile.exists() && outFile.length() > 10000
            mainHandler.post { result.success(ok) }
        } catch (e: Exception) {
            mainHandler.post {
                result.error("BLOCKLIST", e.message, null)
            }
        }
    }

    private fun openFile(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
            val mime = when (file.extension.lowercase()) {
                "mp3", "m4a", "opus", "ogg", "flac", "wav" -> "audio/*"
                "mp4", "mkv", "webm", "mov" -> "video/*"
                else -> "*/*"
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Open with"))
            true
        } catch (e: Exception) {
            false
        }
    }
}
