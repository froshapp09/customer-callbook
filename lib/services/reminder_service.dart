import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/models/customer.dart';

class ReminderService {
  static final instance = ReminderService._();
  ReminderService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _customers = CustomerService();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminders',
        'یادآوری تماس',
        description: 'یادآوری پیگیری مشتری',
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  /// بررسی یادآوری‌های سررسید و نمایش اعلان
  Future<int> checkDueReminders() async {
    await init();
    final all = await _customers.getAll();
    final now = DateTime.now();
    int n = 0;
    for (final c in all) {
      final r = c.reminderAt;
      if (r == null) continue;
      if (r.isAfter(now)) continue;
      await _notifications.show(
        c.id.hashCode & 0x7fffffff,
        'یادآوری تماس: ${c.name}',
        '${Customer.displayPhone(c.phone)}${c.note != null && c.note!.isNotEmpty ? ' · ${c.note}' : ''}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders',
            'یادآوری تماس',
            channelDescription: 'یادآوری پیگیری مشتری',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      // یک‌بار اعلان؛ یادآوری را نگه می‌داریم تا کاربر پاک کند
      n++;
    }
    return n;
  }
}
