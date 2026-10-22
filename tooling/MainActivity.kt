package ir.apadanasleep.customer_callbook

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.database.Cursor
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.CallLog
import android.provider.MediaStore
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import org.json.JSONArray

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

class CallOverlayService : Service() {
    private var wm: WindowManager? = null
    private var root: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent.action == ACTION_DISMISS) {
            remove()
            stopSelf()
            return START_NOT_STICKY
        }
        val number = intent.getStringExtra(EXTRA_NUMBER) ?: ""
        val name = intent.getStringExtra(EXTRA_NAME)
        val note = intent.getStringExtra(EXTRA_NOTE)
        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_SAVE
        show(number, name, note, mode)
        return START_NOT_STICKY
    }

    private fun show(number: String, name: String?, note: String?, mode: String) {
        if (!Settings.canDrawOverlays(this)) {
            // بدون مجوز اورلی — Activity تمام‌صفحه
            try {
                val i = Intent(this, CallAlertActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(CallAlertActivity.EXTRA_NUMBER, number)
                    putExtra(CallAlertActivity.EXTRA_MODE, mode)
                    if (name != null) putExtra(CallAlertActivity.EXTRA_NAME, name)
                    if (note != null) putExtra(CallAlertActivity.EXTRA_NOTE, note)
                }
                startActivity(i)
            } catch (_: Exception) {
            }
            stopSelf()
            return
        }
        remove()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val known = !name.isNullOrBlank()
        val container = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#99000A12"))
            isClickable = true
            setOnClickListener { /* block behind */ }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1F2E"))
                cornerRadius = dp(28).toFloat()
                setStroke(dp(1), Color.parseColor("#33FFFFFF"))
            }
            setPadding(dp(28), dp(28), dp(28), dp(24))
            val lp = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                marginStart = dp(20)
                marginEnd = dp(20)
            }
            layoutParams = lp
        }

        val icon = TextView(this).apply {
            text = if (known) "👤" else "＋"
            gravity = Gravity.CENTER
            textSize = 26f
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#2A2035"))
                setStroke(dp(2), Color.parseColor("#FF8C3A"))
            }
            layoutParams = LinearLayout.LayoutParams(dp(60), dp(60)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(14)
            }
        }
        card.addView(icon)

        val title = TextView(this).apply {
            text = when {
                mode == MODE_SAVE && !known -> "مشتری جدید"
                known -> name
                else -> "مشتری ناشناس"
            }
            setTextColor(Color.parseColor("#FF8C3A"))
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(8) }
        }
        card.addView(title)

        val phoneTv = TextView(this).apply {
            text = "\u200E" + formatPhone(number)
            setTextColor(Color.WHITE)
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(8) }
        }
        card.addView(phoneTv)

        val sub = TextView(this).apply {
            text = when {
                known && !note.isNullOrBlank() -> note
                known -> "در دفترچه شماست"
                mode == MODE_SAVE -> "این شماره در دفترچه شما ثبت نشده"
                else -> "در حال دریافت تماس..."
            }
            setTextColor(Color.parseColor("#99A0B0"))
            textSize = 13f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(20) }
        }
        card.addView(sub)

        if (!known) {
            card.addView(makeBtn("افزودن به دفترچه", Color.parseColor("#00C2D8")) {
                val i = Intent(this, MainActivity::class.java).apply {
                    action = MainActivity.ACTION_ADD_CUSTOMER
                    putExtra(MainActivity.EXTRA_NUMBER, number)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(i)
                remove()
                stopSelf()
            })
        } else {
            card.addView(makeBtn("مشاهده مشتری", Color.parseColor("#6C63FF")) {
                val i = Intent(this, MainActivity::class.java).apply {
                    action = MainActivity.ACTION_OPEN_CUSTOMER
                    putExtra(MainActivity.EXTRA_NUMBER, number)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(i)
                remove()
                stopSelf()
            })
        }
        card.addView(makeBtn("نادیده گرفتن", Color.parseColor("#2A3142"), Color.parseColor("#B0B8C8")) {
            remove()
            stopSelf()
        })

        container.addView(card)
        root = container

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }
        // need focus for buttons
        params.flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON

        try {
            wm?.addView(container, params)
        } catch (_: Exception) {
            stopSelf()
        }
    }

    private fun makeBtn(
        label: String,
        bg: Int,
        fg: Int = Color.WHITE,
        onClick: () -> Unit
    ): Button {
        val density = resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()
        return Button(this).apply {
            text = label
            setTextColor(fg)
            textSize = 15f
            isAllCaps = false
            background = GradientDrawable().apply {
                setColor(bg)
                cornerRadius = dp(16).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(50)
            ).apply { bottomMargin = dp(10) }
            setOnClickListener { onClick() }
        }
    }

    private fun formatPhone(phone: String): String {
        var p = phone.replace(Regex("[\\s\\-()]"), "")
        if (p.startsWith("+98")) p = "0" + p.substring(3)
        if (p.startsWith("0098")) p = "0" + p.substring(4)
        if (p.startsWith("98") && p.length >= 12) p = "0" + p.substring(2)
        return if (p.length == 11 && p.startsWith("09")) {
            "+98 " + p.substring(1, 4) + " " + p.substring(4, 7) + " " + p.substring(7)
        } else phone
    }

    private fun remove() {
        try {
            root?.let { wm?.removeView(it) }
        } catch (_: Exception) {
        }
        root = null
    }

    override fun onDestroy() {
        remove()
        super.onDestroy()
    }

    companion object {
        const val EXTRA_NUMBER = "number"
        const val EXTRA_NAME = "name"
        const val EXTRA_NOTE = "note"
        const val EXTRA_MODE = "mode"
        const val MODE_RING = "ringing"
        const val MODE_SAVE = "save"
        const val ACTION_DISMISS = "ir.apadanasleep.customer_callbook.DISMISS_OVERLAY"

        fun show(
            context: Context,
            number: String,
            name: String?,
            note: String?,
            mode: String
        ) {
            val i = Intent(context, CallOverlayService::class.java).apply {
                putExtra(EXTRA_NUMBER, number)
                putExtra(EXTRA_MODE, mode)
                if (name != null) putExtra(EXTRA_NAME, name)
                if (note != null) putExtra(EXTRA_NOTE, note)
            }
            context.startService(i)
        }
    }
}

class CallAlertActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        try {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } catch (_: Exception) {}

        val number = intent.getStringExtra(EXTRA_NUMBER) ?: ""
        val name = intent.getStringExtra(EXTRA_NAME)
        val note = intent.getStringExtra(EXTRA_NOTE)
        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_RINGING
        val known = !name.isNullOrBlank()

        val density = resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#CC0B0F1A"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setOnClickListener { /* absorb */ }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1F2E"))
                cornerRadius = dp(28).toFloat()
                setStroke(dp(1), Color.parseColor("#33FFFFFF"))
            }
            background = bg
            setPadding(dp(28), dp(32), dp(28), dp(28))
            val lp = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                marginStart = dp(24)
                marginEnd = dp(24)
            }
            layoutParams = lp
        }

        // icon circle
        val iconWrap = TextView(this).apply {
            text = if (known) "👤" else "＋"
            gravity = Gravity.CENTER
            textSize = 28f
            val g = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#2A2035"))
                setStroke(dp(2), Color.parseColor("#FF8C3A"))
            }
            background = g
            layoutParams = LinearLayout.LayoutParams(dp(64), dp(64)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(16)
            }
        }
        card.addView(iconWrap)

        val title = TextView(this).apply {
            text = when {
                mode == MODE_SAVE && !known -> "مشتری جدید"
                mode == MODE_RINGING && known -> name
                mode == MODE_RINGING && !known -> "مشتری ناشناس"
                else -> name ?: "تماس"
            }
            setTextColor(Color.parseColor("#FF8C3A"))
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(10) }
        }
        card.addView(title)

        val phoneTv = TextView(this).apply {
            text = formatPhone(number)
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(8) }
        }
        card.addView(phoneTv)

        val subtitle = TextView(this).apply {
            text = when {
                known && !note.isNullOrBlank() -> note
                known -> "در دفترچه شماست"
                mode == MODE_SAVE -> "این شماره در دفترچه شما ثبت نشده"
                else -> "در حال دریافت تماس..."
            }
            setTextColor(Color.parseColor("#99A0B0"))
            textSize = 14f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dp(24) }
        }
        card.addView(subtitle)

        if (!known) {
            val addBtn = Button(this).apply {
                text = "افزودن به دفترچه"
                setTextColor(Color.WHITE)
                textSize = 16f
                isAllCaps = false
                val g = GradientDrawable().apply {
                    setColor(Color.parseColor("#00C2D8"))
                    cornerRadius = dp(16).toFloat()
                }
                background = g
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(52)
                ).apply { bottomMargin = dp(12) }
                setOnClickListener {
                    val i = packageManager.getLaunchIntentForPackage(packageName)
                    if (i != null) {
                        i.action = ACTION_ADD_CUSTOMER
                        i.putExtra(EXTRA_NUMBER, number)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        startActivity(i)
                    }
                    finish()
                }
            }
            card.addView(addBtn)
        } else {
            val openBtn = Button(this).apply {
                text = "مشاهده مشتری"
                setTextColor(Color.WHITE)
                textSize = 16f
                isAllCaps = false
                val g = GradientDrawable().apply {
                    setColor(Color.parseColor("#6C63FF"))
                    cornerRadius = dp(16).toFloat()
                }
                background = g
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(52)
                ).apply { bottomMargin = dp(12) }
                setOnClickListener {
                    val i = packageManager.getLaunchIntentForPackage(packageName)
                    if (i != null) {
                        i.action = ACTION_OPEN_CUSTOMER
                        i.putExtra(EXTRA_NUMBER, number)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        startActivity(i)
                    }
                    finish()
                }
            }
            card.addView(openBtn)
        }

        val ignoreBtn = Button(this).apply {
            text = "نادیده گرفتن"
            setTextColor(Color.parseColor("#B0B8C8"))
            textSize = 15f
            isAllCaps = false
            val g = GradientDrawable().apply {
                setColor(Color.parseColor("#2A3142"))
                cornerRadius = dp(16).toFloat()
            }
            background = g
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(52)
            )
            setOnClickListener { finish() }
        }
        card.addView(ignoreBtn)

        root.addView(card)
        setContentView(root)
    }

    private fun formatPhone(phone: String): String {
        var p = phone.replace(Regex("[\\s\\-()]"), "")
        if (p.startsWith("+98")) p = "0" + p.substring(3)
        if (p.startsWith("0098")) p = "0" + p.substring(4)
        if (p.startsWith("98") && p.length >= 12) p = "0" + p.substring(2)
        return if (p.length == 11 && p.startsWith("09")) {
            p.substring(0, 4) + " " + p.substring(4, 7) + " " + p.substring(7)
        } else {
            phone
        }
    }

    companion object {
        const val EXTRA_NUMBER = "number"
        const val EXTRA_NAME = "name"
        const val EXTRA_NOTE = "note"
        const val EXTRA_MODE = "mode"
        const val MODE_RINGING = "ringing"
        const val MODE_SAVE = "save"
        const val ACTION_ADD_CUSTOMER = "ir.apadanasleep.customer_callbook.ADD_CUSTOMER"
        const val ACTION_OPEN_CUSTOMER = "ir.apadanasleep.customer_callbook.OPEN_CUSTOMER"
    }
}

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return

        var number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        if (!number.isNullOrBlank()) {
            lastNumber = number
            lastWasIncoming = (state == TelephonyManager.EXTRA_STATE_RINGING)
        }

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (number.isNullOrBlank()) number = lastNumber
                if (number.isNullOrBlank()) {
                    postNotif(context, "تماس ورودی", "شماره در دسترس نیست", null, null, MODE_RING)
                    return
                }
                lastWasIncoming = true
                lastNumber = number
                savePending(context, number, MODE_RING)
                val c = findCustomer(context, number)
                if (c != null) {
                    openAlert(context, number, c.first, c.third, MODE_RING)
                    postNotif(context, "تماس: ${c.first}", ltr(formatPhone(number)), number, c.first, MODE_RING)
                } else {
                    openAlert(context, number, null, null, MODE_RING)
                    postNotif(context, "مشتری ناشناس", ltr(formatPhone(number)) + " · در دفترچه نیست", number, null, MODE_RING)
                }
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // پاسخ داده شد یا تماس خروجی — فقط شماره را نگه دار
                if (!number.isNullOrBlank()) lastNumber = number
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                val n = when {
                    !number.isNullOrBlank() -> number
                    !lastNumber.isNullOrBlank() -> lastNumber
                    else -> lastKnownNumber(context)
                } ?: return

                // فقط بعد از تماس ورودی ناشناس پیشنهاد ذخیره بده (نه تماس خروجی)
                if (!lastWasIncoming) {
                    lastNumber = null
                    return
                }
                lastWasIncoming = false
                lastNumber = null

                val c = findCustomer(context, n)
                if (c == null) {
                    savePending(context, n, MODE_SAVE)
                    openAlert(context, n, null, null, MODE_SAVE)
                    postNotif(
                        context,
                        "مشتری جدید",
                        ltr(formatPhone(n)) + " · ذخیره شود؟",
                        n,
                        null,
                        MODE_SAVE
                    )
                }
            }
        }
    }

    private fun savePending(context: Context, number: String, mode: String) {
        try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.pending_add_phone", number)
                .putString("flutter.pending_add_mode", mode)
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun openAlert(
        context: Context,
        number: String,
        name: String?,
        note: String?,
        mode: String
    ) {
        // پاپ‌آپ روی صفحه (نه فقط نوار اعلان)
        try {
            CallOverlayService.show(context, number, name, note, mode)
        } catch (_: Exception) {
            try {
                val i = Intent(context, CallAlertActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(CallAlertActivity.EXTRA_NUMBER, number)
                    putExtra(CallAlertActivity.EXTRA_MODE, mode)
                    if (name != null) putExtra(CallAlertActivity.EXTRA_NAME, name)
                    if (note != null) putExtra(CallAlertActivity.EXTRA_NOTE, note)
                }
                context.startActivity(i)
            } catch (_: Exception) {
            }
        }
    }

    private fun postNotif(
        context: Context,
        title: String,
        body: String,
        number: String?,
        name: String?,
        mode: String
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "incoming_calls_v2"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                channelId,
                "تماس‌های ورودی",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "پاپ‌آپ و ذخیره مشتری هنگام تماس"
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                enableVibration(true)
            }
            nm.createNotificationChannel(ch)
        }

        // باز کردن اپ برای ذخیره (قابل اطمینان‌تر از Activity شفاف)
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_ADD_CUSTOMER
            putExtra(MainActivity.EXTRA_NUMBER, number ?: "")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val mainPi = PendingIntent.getActivity(
            context, 2010, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alertIntent = Intent(context, CallAlertActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(CallAlertActivity.EXTRA_NUMBER, number ?: "")
            putExtra(CallAlertActivity.EXTRA_MODE, mode)
            if (name != null) putExtra(CallAlertActivity.EXTRA_NAME, name)
        }
        val fullPi = PendingIntent.getActivity(
            context, 2011, alertIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(mainPi)
            .setFullScreenIntent(fullPi, true)

        if (number != null && name == null) {
            builder.addAction(
                android.R.drawable.ic_input_add,
                "ذخیره در دفترچه",
                mainPi
            )
        }

        nm.notify(2001, builder.build())
    }

    private fun ltr(s: String): String = "\u200E$s\u200E"

    private fun lastKnownNumber(context: Context): String? {
        return try {
            context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE),
                null, null,
                CallLog.Calls.DATE + " DESC"
            )?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun findCustomer(context: Context, phone: String): Triple<String, String, String?>? {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
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

    private fun formatPhone(phone: String): String {
        val p = normalize(phone)
        return if (p.length == 11 && p.startsWith("09")) {
            p.substring(0, 4) + " " + p.substring(4, 7) + " " + p.substring(7)
        } else p
    }

    companion object {
        @Volatile private var lastNumber: String? = null
        @Volatile private var lastWasIncoming: Boolean = false
        const val MODE_RING = "ringing"
        const val MODE_SAVE = "save"
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Manifest PHONE_STATE receiver is enough; boot just ensures app data is warm.
    }
}
