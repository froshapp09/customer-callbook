import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';

class CallListenerService {
  static final CallListenerService _instance = CallListenerService._();
  factory CallListenerService() => _instance;
  CallListenerService._();

  final _customerService = CustomerService();
  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<PhoneState>? _sub;
  bool _isListening = false;
  bool _notifReady = false;
  BuildContext? _context;

  Future<void> initNotifications() async {
    if (_notifReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _notifications.initialize(initSettings);
    _notifReady = true;
  }

  Future<bool> requestPermissions() async {
    final phone = await Permission.phone.request();
    await Permission.notification.request();
    return phone.isGranted;
  }

  Future<void> startListening(BuildContext context) async {
    _context = context;
    if (_isListening) return;

    await initNotifications();
    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('مجوز تماس داده نشد');
      return;
    }

    _isListening = true;
    _sub = PhoneState.stream.listen((event) async {
      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        final number = event.number ?? '';
        if (number.isEmpty) return;

        final customer = await _customerService.findByPhone(number);
        await _customerService.recordCall(number, name: customer?.name);

        // نوتیفیکیشن قوی (حتی اگر اپ در پس‌زمینه باشد)
        await _showCallNotification(number, customer);

        // پاپ‌آپ اگر اپ باز باشد
        if (_context != null && _context!.mounted) {
          _showIncomingPopup(_context!, number, customer);
        }
      }
    });
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _isListening = false;
  }

  Future<void> _showCallNotification(String number, Customer? customer) async {
    final title = customer?.name ?? 'تماس ورودی';
    final body = customer != null
        ? '$number  •  ${customer.callCount} تماس قبلی'
        : '$number  •  مشتری جدید';

    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'تماس‌های ورودی',
      channelDescription: 'نمایش اطلاعات تماس‌گیرنده',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
    );

    await _notifications.show(
      1001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  void _showIncomingPopup(BuildContext context, String number, Customer? customer) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'بستن',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E293B)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (customer != null ? const Color(0xFF14B8A6) : const Color(0xFFF59E0B))
                            .withOpacity(0.15),
                      ),
                      child: Icon(
                        customer != null ? Icons.person_rounded : Icons.person_add_rounded,
                        size: 36,
                        color: customer != null ? const Color(0xFF14B8A6) : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      customer?.name ?? 'مشتری جدید',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      number,
                      style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8), letterSpacing: 1),
                    ),
                    if (customer != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          '${customer.callCount} تماس قبلی',
                          style: const TextStyle(
                            color: Color(0xFF14B8A6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (customer.note != null && customer.note!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          customer.note!,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Color(0xFF1E293B)),
                              ),
                            ),
                            child: const Text('بستن'),
                          ),
                        ),
                        if (customer == null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddCustomerPage(initialPhone: number),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('افزودن', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
