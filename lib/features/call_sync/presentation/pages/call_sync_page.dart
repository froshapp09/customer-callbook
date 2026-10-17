import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';

class CallSyncPage extends StatefulWidget {
  const CallSyncPage({super.key});

  @override
  State<CallSyncPage> createState() => _CallSyncPageState();
}

class _CallSyncPageState extends State<CallSyncPage> {
  final _service = CustomerService();
  List<CallLogEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // مجوز تاریخچه تماس
      var status = await Permission.phone.status;
      if (!status.isGranted) {
        status = await Permission.phone.request();
      }

      // بعضی گوشی‌ها call log را جدا می‌خواهند
      final logsStatus = await Permission.phone.request();
      if (!logsStatus.isGranted) {
        setState(() {
          _loading = false;
          _error = 'مجوز تلفن / تاریخچه تماس داده نشده.\nاز تنظیمات برنامه → مجوزها فعال کنید.';
        });
        return;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final from = startOfDay.millisecondsSinceEpoch;

      // تماس‌های امروز + دیروز برای اطمینان
      final iterable = await CallLog.query(
        dateFrom: from - (24 * 60 * 60 * 1000),
      );

      final list = iterable.toList();
      // فقط ورودی و ازدست‌رفته اولویت
      list.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'خطا در خواندن تاریخچه تماس:\n$e\n\nمجوز «تلفن» و در صورت وجود «تاریخچه تماس» را در تنظیمات گوشی بدهید.';
      });
    }
  }

  String _typeLabel(CallType? t) {
    switch (t) {
      case CallType.incoming:
        return 'ورودی';
      case CallType.outgoing:
        return 'خروجی';
      case CallType.missed:
        return 'از دست رفته';
      case CallType.rejected:
        return 'رد شده';
      default:
        return 'تماس';
    }
  }

  Color _typeColor(CallType? t) {
    switch (t) {
      case CallType.incoming:
        return AppColors.success;
      case CallType.outgoing:
        return AppColors.info;
      case CallType.missed:
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  String _timeLabel(int? ts) {
    if (ts == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'امروز $h:$m';
    if (day == today.subtract(const Duration(days: 1))) return 'دیروز $h:$m';
    return '${dt.month}/${dt.day} $h:$m';
  }

  Future<void> _addOrUpdate(CallLogEntry e) async {
    final phone = (e.number ?? '').trim();
    if (phone.isEmpty) return;

    final existing = await _service.findByPhone(phone);
    if (existing != null) {
      // ثبت تماس
      await _service.recordCall(phone, name: existing.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تماس برای «${existing.name}» ثبت شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      // نام از call log یا مخاطبین
      String name = (e.name ?? '').trim();
      if (name.isEmpty || name == phone) {
        name = await _service.lookupNameFromDeviceContacts(phone) ?? '';
      }

      if (name.isEmpty) {
        // برو صفحه افزودن با شماره پر شده
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddCustomerPage(initialPhone: phone),
          ),
        );
      } else {
        await _service.add(Customer(
          name: name,
          phone: phone,
          callCount: 1,
          firstCallAt: e.timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(e.timestamp!)
              : DateTime.now(),
          lastCallAt: e.timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(e.timestamp!)
              : DateTime.now(),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('«$name» اضافه شد'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
    _load();
  }

  Future<void> _addAllMissing() async {
    int added = 0;
    final seen = <String>{};
    for (final e in _entries) {
      final phone = (e.number ?? '').trim();
      if (phone.isEmpty) continue;
      final key = phone.replaceAll(RegExp(r'\D'), '');
      if (seen.contains(key)) continue;
      seen.add(key);

      final existing = await _service.findByPhone(phone);
      if (existing != null) continue;

      String name = (e.name ?? '').trim();
      if (name.isEmpty || name == phone) {
        name = await _service.lookupNameFromDeviceContacts(phone) ?? phone;
      }
      await _service.add(Customer(
        name: name,
        phone: phone,
        callCount: 1,
        firstCallAt: e.timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(e.timestamp!)
            : DateTime.now(),
        lastCallAt: e.timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(e.timestamp!)
            : DateTime.now(),
      ));
      added++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$added مشتری جدید اضافه شد'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تماس‌های گوشی'),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _addAllMissing,
              child: const Text('افزودن همه جدید'),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_disabled, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => openAppSettings(),
                          child: const Text('باز کردن تنظیمات مجوزها'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: const Text('تلاش مجدد')),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? const Center(
                      child: Text('تماس اخیری پیدا نشد', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final e = _entries[index];
                        final phone = e.number ?? '—';
                        final name = (e.name != null && e.name!.trim().isNotEmpty) ? e.name!.trim() : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone_callback, color: _typeColor(e.callType), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name ?? phone,
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      if (name != null)
                                        Text(phone, style: Theme.of(context).textTheme.bodySmall),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_typeLabel(e.callType)}  •  ${_timeLabel(e.timestamp)}',
                                        style: TextStyle(color: _typeColor(e.callType), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _addOrUpdate(e),
                                  child: const Text('افزودن'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
