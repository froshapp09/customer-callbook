package ir.apadanasleep.customer_callbook

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import org.json.JSONArray

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return

        var number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        if (number.isNullOrBlank()) {
            number = lastKnownNumber(context)
        }

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (number.isNullOrBlank()) {
                    showNotification(context, "تماس ورودی", "شماره در دسترس نیست", null, null, CallAlertActivity.MODE_RINGING)
                    return
                }
                val c = findCustomer(context, number)
                if (c != null) {
                    openAlert(context, number, c.first, c.third, CallAlertActivity.MODE_RINGING)
                    showNotification(context, "تماس: ${c.first}", formatPhone(number), number, c.first, CallAlertActivity.MODE_RINGING)
                } else {
                    openAlert(context, number, null, null, CallAlertActivity.MODE_RINGING)
                    showNotification(context, "مشتری ناشناس", formatPhone(number), number, null, CallAlertActivity.MODE_RINGING)
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                if (number.isNullOrBlank()) return
                val c = findCustomer(context, number)
                if (c == null) {
                    // بعد از تماس — پیشنهاد ذخیره
                    openAlert(context, number, null, null, CallAlertActivity.MODE_SAVE)
                    showNotification(context, "مشتری جدید", formatPhone(number) + " — ذخیره شود؟", number, null, CallAlertActivity.MODE_SAVE)
                }
            }
        }
    }

    private fun openAlert(
        context: Context,
        number: String,
        name: String?,
        note: String?,
        mode: String
    ) {
        try {
            val i = Intent(context, CallAlertActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(CallAlertActivity.EXTRA_NUMBER, number)
                putExtra(CallAlertActivity.EXTRA_MODE, mode)
                if (name != null) putExtra(CallAlertActivity.EXTRA_NAME, name)
                if (note != null) putExtra(CallAlertActivity.EXTRA_NOTE, note)
            }
            context.startActivity(i)
        } catch (_: Exception) {
            // fallback: notification full-screen intent only
        }
    }

    private fun showNotification(
        context: Context,
        title: String,
        body: String,
        number: String?,
        name: String?,
        mode: String
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "incoming_calls"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                channelId,
                "تماس‌های ورودی",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "پاپ‌آپ شناسایی مشتری هنگام تماس"
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(ch)
        }

        val alertIntent = Intent(context, CallAlertActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(CallAlertActivity.EXTRA_NUMBER, number ?: "")
            putExtra(CallAlertActivity.EXTRA_MODE, mode)
            if (name != null) putExtra(CallAlertActivity.EXTRA_NAME, name)
        }
        val fullPi = PendingIntent.getActivity(
            context, 2002, alertIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val n = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(fullPi)
            .setFullScreenIntent(fullPi, true)
            .build()
        nm.notify(2001, n)
    }

    private fun lastKnownNumber(context: Context): String? {
        return try {
            context.contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                arrayOf(android.provider.CallLog.Calls.NUMBER),
                null, null,
                android.provider.CallLog.Calls.DATE + " DESC"
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
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
}
