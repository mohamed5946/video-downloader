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
import io.flutter.plugin.common.MethodCall
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
    // v1.0.3: serialize setup attempts — a second init call while one
    // is in progress waits for the first attempt's outcome instead of
    // starting a second extraction.
    private val engineInitLock = Any()
    private var engineInitInProgress = false
    private val pendingInitResults = mutableListOf<MethodChannel.Result>()
    private var adblockChannel: MethodChannel? = null
    private var vpnConsentIntent: Intent? = null

    companion object {
        private const val VPN_REQUEST_CODE = 9001
        // v1.0.6: kill a download process that emits no output lines
        // for this long (stuck merge / stalled transfer) instead of
        // leaving the card at 100% forever.
        private const val WATCHDOG_SILENCE_MS = 5 * 60 * 1000L
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // v1.0.4: never let the consent result crash the app.
        try {
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
        } catch (t: Throwable) {
            android.util.Log.e(
                "SnapDL-AdBlock",
                "VPN consent result failed: ${t.javaClass.simpleName}: ${t.message}"
            )
            try {
                adblockChannel?.invokeMethod(
                    "vpnConsentResult", mapOf("granted" to false)
                )
            } catch (_: Throwable) {}
        }
    }

    // v1.0.4: starting the VPN service must return success/failure to the
    // caller instead of throwing (a throw here used to kill the app with
    // "SnapDL has stopped" right after the VPN icon appeared).
    private fun startAdBlockService(): Boolean {
        return try {
            val intent = Intent(this, AdBlockVpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (t: Throwable) {
            android.util.Log.e(
                "SnapDL-AdBlock",
                "Could not start ad blocker service: ${t.javaClass.simpleName}: ${t.message}"
            )
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        adblockChannel = MethodChannel(messenger, "com.valor.snapdl/adblock")
        adblockChannel?.setMethodCallHandler { call, result ->
            // v1.0.4: every adblock call is guarded — a native failure
            // answers the Dart side with an error instead of crashing.
            try {
                handleAdblockCall(call, result)
            } catch (t: Throwable) {
                android.util.Log.e(
                    "SnapDL-AdBlock",
                    "Adblock call ${call.method} failed: ${t.javaClass.simpleName}: ${t.message}"
                )
                try {
                    result.error("ADBLOCK", t.message, null)
                } catch (_: Throwable) {}
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
                        // v1.0.6: expected total bytes (video+audio) for
                        // overall progress, and the title for matching
                        // files already on disk (resume seeding).
                        val expectedTotalBytes =
                            (call.argument<Number>("expectedTotalBytes")
                                ?.toLong()) ?: 0L
                        val title = call.argument<String>("title") ?: ""
                        Thread {
                            runDownload(
                                id, url, formatId, audioOnly,
                                expectedTotalBytes, title, result
                            )
                        }.start()
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
                    "freeSpaceMb" -> result.success(freeInternalStorageMb())
                    // v1.0.5: update the download tool (the bundled
                    // extractor) to its latest release — a stale bundled
                    // version cannot read sites that changed their pages
                    // (TikTok, 2026-11-11 field report). Runs on a worker
                    // thread: the library call does network I/O.
                    "updateTool" -> updateTool(result)
                    "openFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        result.success(openFile(path))
                    }
                    // v1.0.7: install a downloaded update APK via the
                    // system installer (user consent in the installer
                    // UI — no silent install, no new permission).
                    "installUpdate" -> {
                        val path = call.argument<String>("path") ?: ""
                        result.success(installUpdate(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // v1.0.4: the actual adblock calls, invoked through the guarded
    // wrapper above — a failure here answers Dart with an error.
    private fun handleAdblockCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
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
                    if (startAdBlockService()) {
                        result.success(true)
                    } else {
                        result.error(
                            "ADBLOCK_START",
                            "Could not start the ad blocker service",
                            null
                        )
                    }
                }
                "stop" -> {
                    stopService(Intent(this, AdBlockVpnService::class.java))
                    result.success(true)
                }
                // v1.0.4 FAIL OPEN: the service saves its stop reason
                // (e.g. "Ad blocker stopped: DNS forwarding failed")
                // here when it stops itself; Dart reads it once and
                // logs it in the diagnostics log.
                "stopReason" -> {
                    val prefs = getSharedPreferences(
                        AdBlockVpnService.PREFS, MODE_PRIVATE
                    )
                    val reason =
                        prefs.getString(AdBlockVpnService.KEY_STOP_REASON, null)
                    if (reason != null) {
                        prefs.edit()
                            .remove(AdBlockVpnService.KEY_STOP_REASON)
                            .apply()
                    }
                    result.success(reason)
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

    // ---------------------------------------------------------------- engine

    private fun initEngine(result: MethodChannel.Result) {
        if (engineReady) {
            // v1.0.1: even the cached path must never throw off the main thread.
            try {
                result.success(YoutubeDL.version(applicationContext) ?: "")
            } catch (t: Throwable) {
                // v1.0.5: sanitize — a raw native message must never
                // reach the Dart side (and from there the log / UI).
                result.error("ENGINE_INIT", sanitizeText(t.message ?: "null"), null)
            }
            return
        }
        // v1.0.3: a second call while a setup is in progress queues
        // behind it and gets the same outcome — never a second
        // concurrent extraction.
        val startNow = synchronized(engineInitLock) {
            pendingInitResults.add(result)
            if (engineInitInProgress) {
                false
            } else {
                engineInitInProgress = true
                true
            }
        }
        if (!startNow) return
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
                mainHandler.post { answerPendingInit { it.success(version) } }
            } catch (t: Throwable) {
                // v1.0.1: catch Throwable (incl. UnsatisfiedLinkError and
                // other Errors) — an uncaught Error on this worker thread
                // kills the whole app process ("has stopped" on launch).
                // Always answer the Dart side so it never hangs.
                // v1.0.3: attach diagnostics (type, message, frames, free
                // space) — the message alone was null on the field
                // device, so the log could not name the real cause.
                val diagnostics = buildInitDiagnostics(t)
                mainHandler.post {
                    answerPendingInit {
                        // v1.0.5: sanitize the message too — the details
                        // string is already sanitized by
                        // buildInitDiagnostics, but the message was raw.
                        it.error("ENGINE_INIT", sanitizeText(t.message ?: "null"), diagnostics)
                    }
                }
            }
        }.start()
    }

    /** Answer every init call that waited on the current attempt, then reset. */
    private fun answerPendingInit(answer: (MethodChannel.Result) -> Unit) {
        val waiting = synchronized(engineInitLock) {
            engineInitInProgress = false
            val list = pendingInitResults.toList()
            pendingInitResults.clear()
            list
        }
        waiting.forEach { r ->
            try {
                answer(r)
            } catch (_: Throwable) {
                // A caller that went away must not break the others.
            }
        }
    }

    /**
     * Diagnostics for a failed setup: exception type, message, own-code
     * frames and free internal storage. Library internals are never
     * named here — a type is shown only for generic JVM failures,
     * anything else is reported as a download-library failure, and
     * only our own stack frames are included.
     */
    private fun buildInitDiagnostics(t: Throwable): String {
        val type = sanitizeInitErrorType(t)
        val cause = t.cause?.let { sanitizeInitErrorType(it) }
        val message = sanitizeText(t.message ?: "null")
        val frames = t.stackTrace
            .filter { it.className.startsWith("com.valor.snapdl") }
            .take(3)
            .joinToString("; ") {
                "${it.className.substringAfterLast('.')}.${it.methodName}:${it.lineNumber}"
            }
        val freeMb = freeInternalStorageMb()
        val causePart =
            if (cause != null && cause != type) " cause=$cause" else ""
        return "type=$type$causePart message=$message frames=[$frames] freeMB=$freeMb"
    }

    private fun sanitizeInitErrorType(t: Throwable): String {
        val simple = t.javaClass.simpleName
        val generic = setOf(
            "NullPointerException", "OutOfMemoryError", "UnsatisfiedLinkError",
            "IOException", "IllegalStateException", "IllegalArgumentException",
            "RuntimeException", "Exception", "Error", "StackOverflowError",
            "SecurityException", "NoClassDefFoundError", "ClassNotFoundException",
            "InterruptedException", "TimeoutException",
        )
        return if (simple in generic) simple else "download library error"
    }

    // v1.0.5: update the download tool to its latest release.
    // The library ships a bundled extractor that goes stale when sites
    // change their pages; its own updater fetches the latest release
    // from the official source and stores it for all later extractions.
    // Synchronous network I/O — always called on a worker thread.
    // Never leaks library naming: failures answer with a sanitized
    // message only.
    private fun updateTool(result: MethodChannel.Result) {
        Thread {
            try {
                val status = YoutubeDL.getInstance().updateYoutubeDL(
                    applicationContext,
                    YoutubeDL.UpdateChannel.STABLE
                )
                val name = when (status) {
                    YoutubeDL.UpdateStatus.DONE -> "done"
                    YoutubeDL.UpdateStatus.ALREADY_UP_TO_DATE -> "up_to_date"
                    else -> "done"
                }
                mainHandler.post { result.success(mapOf("status" to name)) }
            } catch (t: Throwable) {
                android.util.Log.e(
                    "SnapDL-Update",
                    "Download tool update failed: ${t.javaClass.simpleName}"
                )
                val msg = sanitizeText(t.message ?: "update failed")
                mainHandler.post { result.error("UPDATE_FAILED", msg, null) }
            }
        }.start()
    }

    /** Strip any library / engine naming from a message before it reaches
     * the diagnostics log (a user-visible surface). */
    private fun sanitizeText(text: String): String {
        var out = text.replace("\n", " ").replace("\r", " ")
        // v1.0.5: strip URLs entirely — a raw extractor error carries a
        // github.com link that must never reach the screen or the log.
        out = out.replace(Regex("https?://\\S+"), "")
        for (word in listOf(
            "yt-dlp", "ytdlp", "youtube-dl", "youtubedl",
            "libffmpeg", "ffmpeg", "engine"
        )) {
            out = out.replace(word, "service", ignoreCase = true)
        }
        return out.replace(Regex("\\s+"), " ").trim().take(300)
    }

    private fun freeInternalStorageMb(): Long {
        return try {
            android.os.StatFs(filesDir.absolutePath)
                .availableBytes / (1024 * 1024)
        } catch (_: Exception) {
            -1
        }
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
                throw Exception("no data returned")
            }
            mainHandler.post { result.success(response.out) }
        } catch (e: Exception) {
            // v1.0.5: sanitize — the raw extractor error carries a
            // github.com link and library naming; the Dart side maps
            // FORMATS to a generic localized message anyway.
            mainHandler.post { result.error("FORMATS", sanitizeText(e.message ?: "extraction failed"), null) }
        }
    }

    // ------------------------------------------------------------- download

    private fun runDownload(
        id: String,
        url: String,
        formatId: String,
        audioOnly: Boolean,
        expectedTotalBytes: Long,
        title: String,
        result: MethodChannel.Result
    ) {
        // v1.0.6: the native silence watchdog — if the download process
        // stops emitting output lines for 5 minutes (the 2026-11-11
        // field case: stuck at 100% with no done/error event), kill it
        // so the Dart side gets an error instead of waiting forever.
        // A normal download emits a line at least every second while
        // data flows; a merge of a short video takes seconds.
        val lastLineAt = java.util.concurrent.atomic.AtomicLong(
            System.currentTimeMillis()
        )
        // AtomicBoolean, not @Volatile: @Volatile is only legal on a
        // class field, not a local variable (CI failed on this).
        val finished = java.util.concurrent.atomic.AtomicBoolean(false)
        val watchdogCancelled = java.util.Collections.synchronizedSet(
            mutableSetOf<String>()
        )
        val watchdog = Thread {
            while (!finished.get()) {
                try {
                    Thread.sleep(10_000)
                } catch (_: InterruptedException) {
                    break
                }
                if (finished.get()) break
                if (System.currentTimeMillis() - lastLineAt.get() >
                    WATCHDOG_SILENCE_MS
                ) {
                    watchdogCancelled.add(id)
                    try {
                        YoutubeDL.destroyProcessById(id)
                    } catch (_: Exception) {
                    }
                    break
                }
            }
        }.apply { isDaemon = true; start() }
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
            // v1.0.6: overall progress across phases (video → audio →
            // merge) from bytes on disk, seeded from any .part / final
            // files already there — so a resume shows its real
            // position at once instead of dropping to 0%.
            val tracker = DownloadProgressTracker(
                expectedTotalBytes, title, downloadDir()
            )
            val seed = tracker.initialOverall()
            if (seed > 0) {
                postEvent(mapOf(
                    "id" to id,
                    "status" to "progress",
                    "progress" to seed * 100.0,
                    "etaSeconds" to -1L,
                    "speed" to ""
                ))
            }
            val response = YoutubeDL.execute(
                request,
                processId = id,
                callback = { progress, eta, line ->
                    lastLineAt.set(System.currentTimeMillis())
                    postProgress(id, progress, eta, line, tracker)
                }
            )
            finished.set(true)
            val filePath = findOutputFile(response.out)
            val size = filePath?.let { File(it).let { f -> if (f.exists()) f.length() else 0L } } ?: 0L
            // v1.0.6: tell the system about the new file right away so
            // it shows in the Gallery immediately (the 2026-11-11 field
            // report: the file was in Downloads but not in the Gallery).
            if (filePath != null) {
                try {
                    android.media.MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(filePath),
                        null,
                        null
                    )
                } catch (_: Exception) {
                }
            }
            postEvent(mapOf(
                "id" to id,
                "status" to "done",
                "filePath" to (filePath ?: ""),
                "fileSizeBytes" to size
            ))
            mainHandler.post { result.success(true) }
        } catch (e: YoutubeDL.CanceledException) {
            finished.set(true)
            if (watchdogCancelled.contains(id)) {
                // Killed by the silence watchdog, not by the user —
                // report an error so the card does not stay "paused".
                postEvent(mapOf(
                    "id" to id,
                    "status" to "error",
                    "error" to "Download stalled"
                ))
                mainHandler.post { result.success(false) }
            } else {
                // Paused or cancelled by the user — Dart already updated the UI.
                postEvent(mapOf("id" to id, "status" to "cancelled"))
                mainHandler.post { result.success(false) }
            }
        } catch (e: Exception) {
            finished.set(true)
            // v1.0.5: sanitize — the raw message can carry extractor
            // naming; the Dart side shows a generic message for it.
            postEvent(mapOf(
                "id" to id,
                "status" to "error",
                "error" to sanitizeText(e.message ?: "Download failed")
            ))
            mainHandler.post { result.success(false) }
        } finally {
            finished.set(true)
        }
    }

    private fun postProgress(
        id: String,
        progress: Float,
        eta: Long,
        line: String,
        tracker: DownloadProgressTracker? = null
    ) {
        val speed = Regex("""(\d+(?:\.\d+)?\s*(?:KiB|MiB|GiB)/s)""")
            .find(line)?.groupValues?.getOrNull(1) ?: ""
        // v1.0.6: overall progress from the tracker (bytes on disk);
        // null keeps the previous value (e.g. extraction lines).
        // The event carries 0..100 — the Dart side divides by 100.
        val overall = tracker?.onLine(line, progress)
        val pct01 = overall ?: run {
            if (progress < 0) return
            (progress / 100.0).coerceIn(0.0, 1.0)
        }
        postEvent(mapOf(
            "id" to id,
            "status" to "progress",
            "progress" to pct01 * 100.0,
            "etaSeconds" to eta,
            "speed" to speed
        ))
    }

    /**
     * v1.0.6: overall download progress from bytes actually on disk.
     * The raw progress lines are per-file, so a bestvideo+bestaudio
     * download restarts the bar at 0% when the audio file starts —
     * the field "resume starts from zero" report. Tracking bytes on
     * disk across phases (and seeding from existing .part / final
     * files on resume) makes the bar monotonic and true.
     */
    private class DownloadProgressTracker(
        private val expectedTotalBytes: Long,
        title: String,
        private val dir: File,
    ) {
        // v1.0.6: first characters of the title as they appear in the
        // saved filename — spaces KEPT (dropping them made the key
        // never match filenames like "عمرك سألت…").
        private val titleKey: String = title.filter {
            it !in "/\\:*?\"<>|" && it.code >= 0x20
        }.take(12)
        private var completedBytes = 0L
        private var currentTotal = 0L
        private var currentDownloaded = 0L

        private val destRe = Regex("""\[download\] Destination: (.+)""")
        private val alreadyRe =
            Regex("""\[download\] (.+) has already been downloaded""")
        private val pctRe = Regex(
            """\[download\]\s+(\d+(?:\.\d+)?)% of\s+(\d+(?:\.\d+)?)\s*(KiB|MiB|GiB|B)"""
        )

        init {
            seedFromDisk()
        }

        private fun matches(f: File): Boolean =
            titleKey.length >= 6 && f.name.contains(titleKey)

        private fun seedFromDisk() {
            val files = try {
                dir.listFiles() ?: return
            } catch (_: Exception) {
                return
            }
            for (f in files) {
                if (!f.isFile || !matches(f)) continue
                if (f.name.endsWith(".part")) {
                    currentDownloaded += f.length()
                } else {
                    completedBytes += f.length()
                }
            }
        }

        /** Overall progress 0..1 right now (seeded from disk). */
        fun initialOverall(): Double {
            if (expectedTotalBytes <= 0) return 0.0
            return ((completedBytes + currentDownloaded).toDouble() /
                expectedTotalBytes).coerceIn(0.0, 1.0)
        }

        /**
         * Feed one output line. Returns overall progress 0..1, or null
         * when this line carries no progress information (keep the
         * previous value).
         */
        fun onLine(line: String, rawPct: Float): Double? {
            destRe.find(line)?.let {
                // A new file starts: the previous file, if it reached
                // its total, counts as complete.
                if (currentTotal > 0 && currentDownloaded >= currentTotal) {
                    completedBytes += currentTotal
                }
                currentTotal = 0L
                currentDownloaded = 0L
                return overall(rawPct)
            }
            alreadyRe.find(line)?.let { m ->
                val f = File(m.groupValues[1].trim())
                if (f.exists()) completedBytes += f.length()
                return overall(rawPct)
            }
            pctRe.find(line)?.let { m ->
                val pct = m.groupValues[1].toDoubleOrNull()
                    ?: return overall(rawPct)
                val total = parseSize(m.groupValues[2], m.groupValues[3])
                if (total > 0) {
                    currentTotal = total
                    currentDownloaded = (pct / 100.0 * total).toLong()
                }
                return overall(rawPct)
            }
            return overall(rawPct)
        }

        private fun overall(rawPct: Float): Double? {
            if (expectedTotalBytes <= 0) {
                return if (rawPct < 0) null
                else (rawPct / 100.0).coerceIn(0.0, 1.0)
            }
            return ((completedBytes + currentDownloaded).toDouble() /
                expectedTotalBytes).coerceIn(0.0, 1.0)
        }

        private fun parseSize(value: String, unit: String): Long {
            val v = value.toDoubleOrNull() ?: return 0L
            val mult = when (unit) {
                "KiB" -> 1024L
                "MiB" -> 1024L * 1024L
                "GiB" -> 1024L * 1024L * 1024L
                else -> 1L
            }
            return (v * mult).toLong()
        }
    }

    private fun postEvent(event: Map<String, Any>) {
        mainHandler.post { eventSink?.success(event) }
    }

    /**
     * Parse the final output file from yt-dlp's log lines.
     *
     * v1.0.6: the Merger output FIRST — the old order checked
     * "[download] Destination:" first, which for a merged
     * bestvideo+bestaudio download is the intermediate video-only
     * file that yt-dlp DELETES after merging, so history pointed at
     * a deleted file and "open" did nothing (2026-11-11 field
     * report). Every candidate must exist and be non-empty.
     */
    private fun findOutputFile(out: String): String? {
        val merged = Regex("""\[Merger\] Merging formats into "(.+)"""")
            .find(out)?.groupValues?.getOrNull(1)?.trim()
            ?.takeIf { File(it).let { f -> f.exists() && f.length() > 0 } }
        if (merged != null) return merged
        val audio = Regex("""\[ExtractAudio\] Destination: (.+)""")
            .find(out)?.groupValues?.getOrNull(1)?.trim()
            ?.takeIf { File(it).let { f -> f.exists() && f.length() > 0 } }
        if (audio != null) return audio
        val dest = Regex("""\[download\] Destination: (.+)""")
            .find(out)?.groupValues?.getOrNull(1)?.trim()
            ?.takeIf { File(it).let { f -> f.exists() && f.length() > 0 } }
        if (dest != null) return dest
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

    // v1.0.7: hand a downloaded update APK to the system installer.
    // Same FileProvider authority pattern as openFile. The installer
    // UI asks the user for consent — this is NOT a silent install,
    // so REQUEST_INSTALL_PACKAGES is not needed and no new permission
    // was added to the manifest.
    private fun installUpdate(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(
                    uri,
                    "application/vnd.android.package-archive"
                )
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
