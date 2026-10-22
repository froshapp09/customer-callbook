package ir.apadanasleep.customer_callbook

import org.json.JSONArray

import androidx.core.app.NotificationCompat

import android.telephony.TelephonyCallback

import android.telephony.PhoneStateListener

import android.os.Looper

import android.os.Handler

import android.content.pm.ServiceInfo

import android.app.Service

import android.app.PendingIntent

import android.app.NotificationManager

import android.app.NotificationChannel

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.CallLog
import android.provider.Settings
import android.provider.MediaStore
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val methodChannelName = "ir.apadanasleep.customer_callbook/call_log"
    private val eventChannelName = "ir.apadanasleep.customer_callbook/phone_state"

    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var lastNumber: String? = null
    private var pendingAddNumber: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureAddIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAddIntent(intent)
    }

    private fun captureAddIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action == ACTION_ADD_CUSTOMER || action == ACTION_OPEN_CUSTOMER) {
            pendingAddNumber = intent.getStringExtra(EXTRA_NUMBER)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openOverlayPermission" -> {
                        try {
                            val uri = Uri.parse("package:$packageName")
                            val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, uri)
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "canDrawOverlays" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    "getPendingAddPhone" -> {
                        var n = pendingAddNumber
                        pendingAddNumber = null
                        if (n.isNullOrBlank()) {
                            try {
                                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                                n = prefs.getString("flutter.pending_add_phone", null)
                                if (!n.isNullOrBlank()) {
                                    prefs.edit()
                                        .remove("flutter.pending_add_phone")
                                        .remove("flutter.pending_add_mode")
                                        .apply()
                                }
                            } catch (_: Exception) {
                            }
                        }
                        result.success(n)
                    }
                    "getRecentCalls" -> {
                        try {
                            val days = call.argument<Int>("days") ?: 2
                            result.success(getRecentCalls(days))
                        } catch (e: SecurityException) {
                            result.error("PERMISSION", "need call log permission", null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "startCallMonitor" -> {
                        try {
                            val i = Intent(this, CallMonitorService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(i)
                            } else {
                                startService(i)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopCallMonitor" -> {
                        try {
                            val i = Intent(this, CallMonitorService::class.java)
                            i.action = CallMonitorService.ACTION_STOP
                            startService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "startPhoneListen" -> {
                        try {
                            startReceiver()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopPhoneListen" -> {
                        try {
                            stopReceiver()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "saveBackupFile" -> {
                        try {
                            val name = call.argument<String>("name") ?: "backup.json"
                            val content = call.argument<String>("content") ?: ""
                            val path = saveBackup(name, content)
                            result.success(path)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun startReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
                val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

                val state = when (stateStr) {
                    TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
                    TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
                    TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
                    else -> return
                }

                if (state == TelephonyManager.CALL_STATE_RINGING) {
                    lastNumber = number
                    val map = hashMapOf<String, Any?>(
                        "status" to "incoming",
                        "number" to (number ?: lastNumber ?: "")
                    )
                    runOnUiThread { eventSink?.success(map) }
                } else if (state == TelephonyManager.CALL_STATE_IDLE && lastState != TelephonyManager.CALL_STATE_IDLE) {
                    val map = hashMapOf<String, Any?>(
                        "status" to "idle",
                        "number" to (lastNumber ?: "")
                    )
                    runOnUiThread { eventSink?.success(map) }
                    lastNumber = null
                }
                lastState = state
            }
        }
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    private fun stopReceiver() {
        try {
            receiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {
        }
        receiver = null
    }

    override fun onDestroy() {
        stopReceiver()
        super.onDestroy()
    }

    private fun getRecentCalls(days: Int): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val from = System.currentTimeMillis() - days.toLong() * 24L * 60L * 60L * 1000L
        val projection = arrayOf(
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION
        )
        val cursor: Cursor? = contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            projection,
            "${CallLog.Calls.DATE} >= ?",
            arrayOf(from.toString()),
            "${CallLog.Calls.DATE} DESC"
        )
        cursor?.use {
            val idxNum = it.getColumnIndex(CallLog.Calls.NUMBER)
            val idxName = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val idxType = it.getColumnIndex(CallLog.Calls.TYPE)
            val idxDate = it.getColumnIndex(CallLog.Calls.DATE)
            var count = 0
            while (it.moveToNext() && count < 200) {
                val number = if (idxNum >= 0) it.getString(idxNum) else null
                val name = if (idxName >= 0) it.getString(idxName) else null
                val typeInt = if (idxType >= 0) it.getInt(idxType) else 0
                val date = if (idxDate >= 0) it.getLong(idxDate) else 0L
                val type = when (typeInt) {
                    CallLog.Calls.INCOMING_TYPE -> "incoming"
                    CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                    CallLog.Calls.MISSED_TYPE -> "missed"
                    CallLog.Calls.REJECTED_TYPE -> "rejected"
                    else -> "other"
                }
                out.add(
                    mapOf(
                        "number" to (number ?: ""),
                        "name" to (name ?: ""),
                        "type" to type,
                        "timestamp" to date
                    )
                )
                count++
            }
        }
        return out
    }

    private fun saveBackup(fileName: String, content: String): String {
        val bytes = content.toByteArray(Charsets.UTF_8)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("cannot create MediaStore entry")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw Exception("cannot open output stream")
            return "Downloads/$fileName"
        }
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, fileName)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }

    companion object {
        const val ACTION_ADD_CUSTOMER = "ir.apadanasleep.customer_callbook.ADD_CUSTOMER"
        const val ACTION_OPEN_CUSTOMER = "ir.apadanasleep.customer_callbook.OPEN_CUSTOMER"
        const val EXTRA_NUMBER = "number"
    }
}

class CallMonitorService : Service() {
    private var tm: TelephonyManager? = null
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var lastNumber: String? = null
    private var wasRinging = false
    private val handler = Handler(Looper.getMainLooper())
    private var modernCallback: TelephonyCallback? = null
    private var legacyListener: PhoneStateListener? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startAsForeground()
        startListen()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopListen()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        startAsForeground()
        if (tm == null) startListen()
        return START_STICKY
    }

    private fun startAsForeground() {
        val chId = "call_monitor_fg"
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                chId,
                "مانیتور تماس",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "سرویس شناسایی تماس فعال است"
                setShowBadge(false)
            }
            nm.createNotificationChannel(ch)
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val pi = if (open != null) {
            PendingIntent.getActivity(
                this, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null
        val n = NotificationCompat.Builder(this, chId)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("دفترچه مشتریان")
            .setContentText("شناسایی تماس فعال است")
            .setOngoing(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(9001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL)
        } else {
            startForeground(9001, n)
        }
    }

    private fun startListen() {
        tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    handleState(state, null)
                }
            }
            modernCallback = cb
            try {
                tm?.registerTelephonyCallback(mainExecutor, cb)
            } catch (e: SecurityException) {
                startLegacy()
            }
        } else {
            startLegacy()
        }
    }

    @Suppress("DEPRECATION")
    private fun startLegacy() {
        legacyListener = object : PhoneStateListener() {
            @Deprecated("Deprecated in Java")
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                handleState(state, phoneNumber)
            }
        }
        try {
            tm?.listen(legacyListener, PhoneStateListener.LISTEN_CALL_STATE)
        } catch (_: Exception) {
        }
    }

    private fun handleState(state: Int, phoneNumber: String?) {
        if (!phoneNumber.isNullOrBlank()) lastNumber = phoneNumber

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                wasRinging = true
                if (!phoneNumber.isNullOrBlank()) lastNumber = phoneNumber
                // اگر شماره نبود کمی بعد از لاگ بخوان
                val num = lastNumber
                if (!num.isNullOrBlank()) {
                    onIncoming(num)
                } else {
                    handler.postDelayed({
                        val n = lastNumber ?: readLatestNumber()
                        if (!n.isNullOrBlank()) {
                            lastNumber = n
                            onIncoming(n)
                        }
                    }, 800)
                }
            }
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (!phoneNumber.isNullOrBlank()) lastNumber = phoneNumber
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (lastState == TelephonyManager.CALL_STATE_IDLE) return
                val incoming = wasRinging
                wasRinging = false
                val num = lastNumber ?: readLatestNumber()
                lastNumber = null
                if (incoming && !num.isNullOrBlank()) {
                    // بعد از قطع تماس ورودی
                    handler.postDelayed({ onCallEnded(num) }, 500)
                }
            }
        }
        lastState = state
    }

    private fun onIncoming(number: String) {
        val c = findCustomer(number)
        if (c != null) {
            CallOverlayService.show(this, number, c.first, c.third, CallOverlayService.MODE_RING)
        } else {
            CallOverlayService.show(this, number, null, null, CallOverlayService.MODE_RING)
        }
        savePending(number, "ringing")
    }

    private fun onCallEnded(number: String) {
        val c = findCustomer(number)
        if (c == null) {
            savePending(number, "save")
            CallOverlayService.show(this, number, null, null, CallOverlayService.MODE_SAVE)
        }
    }

    private fun savePending(number: String, mode: String) {
        try {
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .edit()
                .putString("flutter.pending_add_phone", number)
                .putString("flutter.pending_add_mode", mode)
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun readLatestNumber(): String? {
        return try {
            contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE),
                null, null,
                CallLog.Calls.DATE + " DESC"
            )?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun findCustomer(phone: String): Triple<String, String, String?>? {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val raw = prefs.getString("flutter.customers_v2", null) ?: return null
            val arr = JSONArray(raw)
            val norm = normalize(phone)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val p = normalize(o.optString("phone", ""))
                if (p.isNotEmpty() && (p == norm || p.endsWith(norm.takeLast(10)) || norm.endsWith(p.takeLast(10)))) {
                    return Triple(
                        o.optString("name", phone).ifBlank { phone },
                        o.optString("tag", ""),
                        o.optString("note", null)
                    )
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun normalize(phone: String): String {
        var p = phone.replace(Regex("[\\s\\-()]"), "")
        if (p.startsWith("+98")) p = "0" + p.substring(3)
        if (p.startsWith("0098")) p = "0" + p.substring(4)
        if (p.startsWith("98") && p.length >= 12) p = "0" + p.substring(2)
        return p
    }

    private fun stopListen() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                modernCallback?.let { tm?.unregisterTelephonyCallback(it) }
            } else {
                @Suppress("DEPRECATION")
                legacyListener?.let { tm?.listen(it, PhoneStateListener.LISTEN_NONE) }
            }
        } catch (_: Exception) {
        }
        modernCallback = null
        legacyListener = null
        tm = null
    }

    override fun onDestroy() {
        stopListen()
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "ir.apadanasleep.customer_callbook.STOP_MONITOR"

        fun start(context: Context) {
            val i = Intent(context, CallMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            val i = Intent(context, CallMonitorService::class.java).apply { action = ACTION_STOP }
            context.startService(i)
        }
    }
}
