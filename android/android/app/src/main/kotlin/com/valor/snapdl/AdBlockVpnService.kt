package com.valor.snapdl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

/**
 * DNS-level, system-wide ad blocker.
 *
 * A local VpnService that routes ONLY DNS traffic through itself
 * (the TUN interface carries the DNS server address 10.0.0.1; all other
 * traffic bypasses the VPN, so there is no speed penalty on real data).
 * Every DNS query is checked against a bundled hosts blocklist
 * (StevenBlack unified hosts, ~78k domains, updatable from the app).
 * Blocked domains get a 0.0.0.0 answer (A) / NXDOMAIN (other types);
 * everything else is forwarded to 1.1.1.1 (fallback 8.8.8.8) and the
 * real answer is relayed back.
 *
 * Honest limits (also shown in the UI):
 * - Only one VPN can run at a time — conflicts with other VPN apps.
 * - YouTube video ads are NOT blocked (same domain as the video).
 */
class AdBlockVpnService : VpnService() {

    companion object {
        private const val TAG = "SnapDL-AdBlock"
        private const val CHANNEL_ID = "snapdl_adblock"
        private const val NOTIF_ID = 1001

        // v1.0.4: PREFS / KEY_STOP_REASON are public so MainActivity can
        // read the fail-open reason and surface it in the diagnostics log.
        const val PREFS = "snapdl_adblock"
        const val KEY_STOP_REASON = "adblock_stop_reason"
        private const val KEY_BLOCKED = "blocked_count"
        private const val UPSTREAM_1 = "1.1.1.1"
        private const val UPSTREAM_2 = "8.8.8.8"
        private const val DNS_PORT = 53
        private const val TUN_ADDRESS = "10.0.0.2"
        private const val DNS_ADDRESS = "10.0.0.1"

        // v1.0.4 FAIL OPEN: if upstream DNS forwarding fails this many
        // times in a row, the service stops itself instead of leaving
        // the phone with broken DNS. The user asked for this explicitly:
        // the internet must keep working when the blocker is on.
        private const val MAX_CONSECUTIVE_FORWARD_FAILURES = 3

        @Volatile
        var isRunning = false
            private set

        val blockedCount = AtomicLong(0)
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var tunIn: FileInputStream? = null
    private var tunOut: FileOutputStream? = null
    @Volatile
    private var stopRequested = false
    private val pool = Executors.newCachedThreadPool()
    private val blocked = HashSet<String>()

    // v1.0.4: consecutive failed upstream forwards (reset on any success).
    // Guarded by failOpenLock; only handlePacket's pool threads touch it.
    private var consecutiveForwardFailures = 0
    private val failOpenLock = Any()
    private var failOpenTriggered = false

    override fun onCreate() {
        // v1.0.4: a failure starting the service must never kill the app
        // process ("SnapDL has stopped" in the field). Catch everything,
        // log it, and carry on with an empty blocklist — the service can
        // still start; onStartCommand decides whether it stays up.
        try {
            super.onCreate()
            blockedCount.set(
                getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getLong(KEY_BLOCKED, 0)
            )
            loadBlocklist()
            createNotificationChannel()
        } catch (t: Throwable) {
            Log.e(TAG, "Ad blocker onCreate failed: ${t.javaClass.simpleName}: ${t.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // v1.0.4: the whole startup is guarded — any failure stops the
        // service gracefully (stopSelf) instead of crashing the app.
        try {
            return startCommandGuarded(intent, flags, startId)
        } catch (t: Throwable) {
            Log.e(TAG, "Ad blocker failed to start: ${t.javaClass.simpleName}: ${t.message}")
            try { stopSelf() } catch (_: Throwable) {}
            return START_NOT_STICKY
        }
    }

    private fun startCommandGuarded(intent: Intent?, flags: Int, startId: Int): Int {
        if (isRunning) return START_STICKY
        val builder = Builder()
            .setSession("SnapDL Ad Blocker")
            .addAddress(TUN_ADDRESS, 32)
            .addDnsServer(DNS_ADDRESS)
            // v1.0.4: ONLY the DNS-server route is added — there is
            // deliberately NO default route, so all non-DNS traffic
            // bypasses the VPN untouched and the internet keeps working.
            .addRoute(DNS_ADDRESS, 32)
        val fd = try {
            builder.establish()
        } catch (e: Exception) {
            Log.e(TAG, "Could not establish VPN: ${e.message}")
            null
        }
        if (fd == null) {
            Log.e(TAG, "VPN establish() returned null (another VPN running?)")
            stopSelf()
            return START_NOT_STICKY
        }
        tunFd = fd
        tunIn = FileInputStream(fd.fileDescriptor)
        tunOut = FileOutputStream(fd.fileDescriptor)
        stopRequested = false
        failOpenTriggered = false
        consecutiveForwardFailures = 0
        isRunning = true

        val pending = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("SnapDL Ad Blocker")
            .setContentText("Blocking ads and trackers system-wide")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
        // v1.0.4: startForeground can throw on some devices/Android
        // versions (foreground-service rules) — that must stop the
        // service, never crash the app.
        try {
            startForeground(NOTIF_ID, notification)
        } catch (t: Throwable) {
            Log.e(TAG, "Ad blocker startForeground failed: ${t.javaClass.simpleName}: ${t.message}")
            isRunning = false
            stopSelf()
            return START_NOT_STICKY
        }
        Log.i(TAG, "Ad blocker started (${blocked.size} blocked domains)")
        Thread { readLoop() }.start()
        return START_STICKY
    }

    /**
     * v1.0.4 FAIL OPEN: upstream DNS is dead — stop the service so the
     * phone's normal DNS takes over again instead of blackholing every
     * lookup. The reason is saved for the Dart side, which logs it in
     * the diagnostics log and turns the UI toggle off.
     */
    private fun failOpen() {
        synchronized(failOpenLock) {
            if (failOpenTriggered) return
            failOpenTriggered = true
        }
        Log.e(TAG, "Ad blocker stopped: DNS forwarding failed")
        try {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(
                    KEY_STOP_REASON,
                    "Ad blocker stopped: DNS forwarding failed"
                )
                .apply()
        } catch (_: Throwable) {}
        isRunning = false
        stopRequested = true
        try { stopSelf() } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        stopRequested = true
        isRunning = false
        try { tunIn?.close() } catch (_: IOException) {}
        try { tunOut?.close() } catch (_: IOException) {}
        try { tunFd?.close() } catch (_: IOException) {}
        pool.shutdownNow()
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_BLOCKED, blockedCount.get())
            .apply()
        super.onDestroy()
    }

    // ------------------------------------------------------------- blocklist

    private fun loadBlocklist() {
        blocked.clear()
        val lines: List<String> = try {
            val updated = File(filesDir, "adblock-hosts.txt")
            if (updated.exists() && updated.length() > 0) {
                Log.i(TAG, "Using updated blocklist from app storage")
                updated.readLines()
            } else {
                assets.open("adblock-hosts.txt").bufferedReader().readLines()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Blocklist load failed: ${e.message}")
            emptyList()
        }
        for (line in lines) {
            val t = line.trim()
            if (t.isEmpty() || t.startsWith("#")) continue
            val parts = t.split(Regex("\\s+"))
            if (parts.size >= 2 && (parts[0] == "0.0.0.0" || parts[0] == "127.0.0.1")) {
                blocked.add(parts[1].lowercase())
            }
        }
        Log.i(TAG, "Loaded ${blocked.size} blocked domains")
    }

    /** Exact match, or any parent domain (ads.foo.com is blocked if foo.com is). */
    private fun isBlocked(domain: String): Boolean {
        var d = domain.lowercase().trimEnd('.')
        while (true) {
            if (blocked.contains(d)) return true
            val dot = d.indexOf('.')
            if (dot < 0) return false
            d = d.substring(dot + 1)
        }
    }

    // -------------------------------------------------------------- DNS loop

    private fun readLoop() {
        val buffer = ByteArray(32767)
        while (!stopRequested) {
            val len = try {
                tunIn?.read(buffer) ?: break
            } catch (e: IOException) {
                if (!stopRequested) Log.e(TAG, "TUN read failed: ${e.message}")
                break
            }
            if (len <= 0) continue
            val packet = buffer.copyOf(len)
            pool.execute { handlePacket(packet) }
        }
    }

    private fun handlePacket(packet: ByteArray) {
        try {
            if (packet.size < 20) return
            val ihl = (packet[0].toInt() and 0x0F) * 4
            if (packet[9].toInt() != 17) return // UDP only
            if (packet.size < ihl + 8) return
            val udpStart = ihl
            val srcPort = u16(packet, udpStart)
            val dstPort = u16(packet, udpStart + 2)
            if (dstPort != DNS_PORT) return
            val dnsStart = udpStart + 8
            val dnsLen = packet.size - dnsStart
            if (dnsLen < 12) return
            val dns = packet.copyOfRange(dnsStart, packet.size)
            val (domain, qtype) = parseQuestion(dns) ?: return
            val srcIp = packet.copyOfRange(12, 16)

            if (isBlocked(domain)) {
                blockedCount.incrementAndGet()
                val response = buildBlockedResponse(dns, qtype)
                writePacket(srcIp, srcPort, response)
            } else {
                // v1.0.4 FAIL OPEN: track upstream health. A successful
                // forward resets the counter; consecutive failures trip
                // failOpen() so the phone never sits on broken DNS.
                val response = forwardDns(dns)
                if (response == null) {
                    val failures = synchronized(failOpenLock) {
                        consecutiveForwardFailures += 1
                        consecutiveForwardFailures
                    }
                    if (failures >= MAX_CONSECUTIVE_FORWARD_FAILURES) {
                        failOpen()
                    }
                    return
                }
                synchronized(failOpenLock) { consecutiveForwardFailures = 0 }
                writePacket(srcIp, srcPort, response)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Packet handling failed: ${e.message}")
        }
    }

    /** Extract the queried domain name + QTYPE from a DNS message. */
    private fun parseQuestion(dns: ByteArray): Pair<String, Int>? {
        if (dns.size < 12) return null
        val qdCount = u16(dns, 4)
        if (qdCount != 1) return null
        val labels = StringBuilder()
        var pos = 12
        while (pos < dns.size) {
            val len = dns[pos].toInt() and 0xFF
            if (len == 0) break
            if (len and 0xC0 != 0) return null // compression not expected here
            if (pos + 1 + len > dns.size) return null
            if (labels.isNotEmpty()) labels.append('.')
            labels.append(String(dns, pos + 1, len, Charsets.US_ASCII))
            pos += 1 + len
        }
        if (labels.isEmpty()) return null
        if (pos + 4 > dns.size) return null
        val qtype = u16(dns, pos + 1)
        return labels.toString() to qtype
    }

    /** NXDOMAIN for non-A queries; 0.0.0.0 answer for A queries. */
    private fun buildBlockedResponse(query: ByteArray, qtype: Int): ByteArray {
        val id = query.copyOfRange(0, 2)
        val flags: Short = if (qtype == 1) {
            0x8180.toShort() // QR + RD + RA, NOERROR
        } else {
            0x8183.toShort() // QR + RD + RA, NXDOMAIN
        }
        val question = query.copyOfRange(12, query.size)
        val out = ByteBuffer.allocate(512)
        out.put(id)
        out.putShort(flags)
        out.putShort(1) // QDCOUNT
        out.putShort(if (qtype == 1) 1 else 0) // ANCOUNT
        out.putShort(0) // NSCOUNT
        out.putShort(0) // ARCOUNT
        out.put(question)
        if (qtype == 1) {
            // Answer: pointer to QNAME (0xC00C), type A, class IN, TTL 60,
            // RDLENGTH 4, RDATA 0.0.0.0
            out.putShort(0xC00C.toShort())
            out.putShort(1)
            out.putShort(1)
            out.putInt(60)
            out.putShort(4)
            out.put(byteArrayOf(0, 0, 0, 0))
        }
        val result = ByteArray(out.position())
        out.rewind()
        out.get(result)
        return result
    }

    /** Send the raw DNS query to an upstream resolver and return its answer. */
    private fun forwardDns(query: ByteArray): ByteArray? {
        // v1.0.4: short timeout (~2.5s) per upstream; try 1.1.1.1 first,
        // fall back to 8.8.8.8. A null return counts as one failed
        // forward for the fail-open counter (see handlePacket).
        for (upstream in listOf(UPSTREAM_1, UPSTREAM_2)) {
            try {
                DatagramSocket().use { socket ->
                    socket.soTimeout = 2500
                    val addr = InetAddress.getByName(upstream)
                    socket.send(DatagramPacket(query, query.size, addr, DNS_PORT))
                    val buf = ByteArray(4096)
                    val resp = DatagramPacket(buf, buf.size)
                    socket.receive(resp)
                    return resp.data.copyOf(resp.length)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Upstream $upstream failed: ${e.message}")
            }
        }
        return null
    }

    /** Wrap a DNS payload in IPv4+UDP headers addressed back to the client. */
    private fun writePacket(dstIp: ByteArray, dstPort: Int, dnsPayload: ByteArray) {
        val out = tunOut ?: return
        val total = 20 + 8 + dnsPayload.size
        val buf = ByteBuffer.allocate(total)
        // IPv4 header
        buf.put(0x45.toByte())
        buf.put(0) // TOS
        buf.putShort(total.toShort())
        buf.putShort(0) // ID
        buf.putShort(0) // flags/fragment
        buf.put(64.toByte()) // TTL
        buf.put(17.toByte()) // UDP
        buf.putShort(0) // checksum (filled below)
        buf.put(InetAddress.getByName(DNS_ADDRESS).address) // src = our DNS
        buf.put(dstIp) // dst = original client
        // UDP header
        buf.putShort(DNS_PORT.toShort())
        buf.putShort(dstPort.toShort())
        buf.putShort((8 + dnsPayload.size).toShort())
        buf.putShort(0) // UDP checksum 0 is legal for IPv4
        buf.put(dnsPayload)
        val packet = buf.array()
        // IP header checksum
        val checksum = ipChecksum(packet, 0, 20)
        packet[10] = (checksum ushr 8).toByte()
        packet[11] = (checksum and 0xFF).toByte()
        synchronized(out) {
            try {
                out.write(packet)
            } catch (e: IOException) {
                Log.e(TAG, "TUN write failed: ${e.message}")
            }
        }
    }

    private fun ipChecksum(buf: ByteArray, offset: Int, len: Int): Int {
        var sum = 0L
        var i = offset
        while (i < offset + len - 1) {
            sum += ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF)
            i += 2
        }
        if (i < offset + len) sum += (buf[i].toInt() and 0xFF) shl 8
        while (sum ushr 16 != 0L) sum = (sum and 0xFFFF) + (sum ushr 16)
        return sum.inv().toInt() and 0xFFFF
    }

    private fun u16(buf: ByteArray, pos: Int): Int =
        ((buf[pos].toInt() and 0xFF) shl 8) or (buf[pos + 1].toInt() and 0xFF)

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SnapDL Ad Blocker",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Shows while the ad blocker VPN is running"
            val manager = getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
