import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/models/customer.dart';

/// شنود تماس ورودی + اعلان نام مشتری
class CallListenerService {
  static final CallListenerService instance = CallListenerService._();
  factory CallListenerService() => instance;
  CallListenerService._();

  static const _prefKey = 'call_detect_enabled';
  final _customerService = CustomerService();
  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<PhoneState>? _sub;
  bool _isListening = false;
  bool _notifReady = false;
  bool get isListening => _isListening;

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefKey, v);
  }

  Future<void> initNotifications() async {
    if (_notifReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'incoming_calls',
        'تماس‌های ورودی',
        description: 'نمایش نام مشتری هنگام تماس',
        importance: Importance.max,
        playSound: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'call_monitor',
        'شناسایی تماس',
        description: 'سرویس شناسایی تماس فعال است',
        importance: Importance.low,
      ),
    );
    _notifReady = true;
  }

  Future<bool> requestPermissions() async {
    final phone = await Permission.phone.request();
    await Permission.notification.request();
    // call log helps match numbers
    await Permission.phone.request();
    try {
      // ignore: deprecated_member_use
      await Permission.phone.request();
    } catch (_) {}
    return phone.isGranted;
  }

  /// از تنظیمات یا استارت اپ
  Future<bool> enableAndStart() async {
    await initNotifications();
    final ok = await requestPermissions();
    if (!ok) return false;
    await setEnabled(true);
    await startListening();
    await _showMonitorNotification();
    return _isListening;
  }

  Future<void> disableAndStop() async {
    await setEnabled(false);
    stopListening();
    await _notifications.cancel(9001);
  }

  /// اگر قبلاً فعال شده، دوباره شروع کن (مثلاً بعد از باز شدن اپ)
  Future<void> restoreIfEnabled() async {
    if (await isEnabled()) {
      await initNotifications();
      if (await Permission.phone.isGranted) {
        await startListening();
        await _showMonitorNotification();
      }
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;
    await initNotifications();
    if (!await Permission.phone.isGranted) {
      debugPrint('CallListener: no phone permission');
      return;
    }
    _isListening = true;
    _sub?.cancel();
    _sub = PhoneState.stream.listen((event) async {
      try {
        if (event.status != PhoneStateStatus.CALL_INCOMING) return;
        final number = (event.number ?? '').trim();
        if (number.isEmpty) return;

        final customer = await _customerService.findByPhone(number);
        await _customerService.recordCall(number, name: customer?.name, type: 1);
        await _showCallNotification(number, customer);
      } catch (e) {
        debugPrint('CallListener error: $e');
      }
    }, onError: (e) {
      debugPrint('CallListener stream error: $e');
    });
    debugPrint('CallListener: started');
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _isListening = false;
  }

  Future<void> _showMonitorNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'call_monitor',
      'شناسایی تماس',
      channelDescription: 'سرویس شناسایی تماس فعال است',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    await _notifications.show(
      9001,
      'شناسایی تماس فعال است',
      'با تماس ورودی، نام مشتری نمایش داده می‌شود',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _showCallNotification(String number, Customer? customer) async {
    final title = customer != null ? 'تماس: ${customer.name}' : 'تماس ورودی';
    final body = customer != null
        ? '${Customer.displayPhone(number)} · ${customer.callCount} تماس قبلی · ${customer.tag}'
        : '${Customer.displayPhone(number)} · در دفترچه نیست';

    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'تماس‌های ورودی',
      channelDescription: 'نمایش اطلاعات تماس‌گیرنده',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    await _notifications.show(
      1001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
