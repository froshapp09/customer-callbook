package ir.apadanasleep.customer_callbook

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
                            CallMonitorService.start(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopCallMonitor" -> {
                        try {
                            CallMonitorService.stop(this)
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
