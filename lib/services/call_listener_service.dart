import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';

class CallListenerService {
  static final CallListenerService _instance = CallListenerService._();
  factory CallListenerService() => _instance;
  CallListenerService._();

  final _customerService = CustomerService();
  StreamSubscription<PhoneState>? _sub;
  bool _isListening = false;

  Future<bool> requestPermissions() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  Future<void> startListening(BuildContext context) async {
    if (_isListening) return;

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

        if (context.mounted) {
          _showIncomingPopup(context, number, customer);
        }
      }
    });
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _isListening = false;
  }

  void _showIncomingPopup(BuildContext context, String number, Customer? customer) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: const Color(0xFF141B2D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    customer != null ? Icons.person : Icons.person_add,
                    size: 48,
                    color: customer != null ? const Color(0xFF5EEAD4) : const Color(0xFFFBBF24),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customer?.name ?? 'مشتری جدید',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(number, style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                  if (customer != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5EEAD4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${customer.callCount} تماس قبلی',
                        style: const TextStyle(color: Color(0xFF5EEAD4), fontSize: 13),
                      ),
                    ),
                    if (customer.note != null && customer.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        customer.note!,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
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
                            child: const Text('افزودن'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
