package ir.apadanasleep.daftarche

import android.database.Cursor
import android.provider.CallLog
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ir.apadanasleep.daftarche/call_log"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getRecentCalls") {
                    try {
                        val days = (call.argument<Int>("days") ?: 2)
                        result.success(getRecentCalls(days))
                    } catch (e: SecurityException) {
                        result.error("PERMISSION", "need call log permission", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
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
