package ir.apadanasleep.customer_callbook

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.CallLog
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                    "startPhoneListen" -> {
                        try {
                            startReceiver()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopPhoneListen" -> {
                        stopReceiver()
                        result.success(true)
                    }
                    "saveToDownloads" -> {
                        try {
                            val content = call.argument<String>("content") ?: ""
                            val fileName = call.argument<String>("fileName") ?: "daftarche_backup.json"
                            val path = saveToDownloads(content, fileName)
                            result.success(path)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    try {
                        startReceiver()
                    } catch (e: Exception) {
                        events?.error("ERROR", e.message, null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /** ذخیره مستقیم در Download/Daftarche بدون صفحه اشتراک */
    private fun saveToDownloads(content: String, fileName: String): String {
        val relativePath = "Download/Daftarche"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            }
            // حذف قبلی با همین نام در همان پوشه (اختیاری ساده: همیشه نام جدید با timestamp)
            val resolver = contentResolver
            val uri: Uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("نتوانست فایل بسازد")
            resolver.openOutputStream(uri)?.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                ?: throw Exception("نتوانست بنویسد")
            return "/storage/emulated/0/$relativePath/$fileName"
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Daftarche")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            FileOutputStream(file).use { it.write(content.toByteArray(Charsets.UTF_8)) }
            return file.absolutePath
        }
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
}
