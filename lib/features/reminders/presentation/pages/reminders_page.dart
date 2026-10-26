import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/core/utils/jalali.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';
import 'package:customer_callbook/shared/widgets/customer_avatar.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _service = CustomerService();
  List<Customer> _due = [];
  List<Customer> _up = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final due = await _service.remindersDueToday();
    final up = await _service.remindersUpcoming();
    if (mounted) setState(() { _due = due; _up = up; _loading = false; });
  }

  Future<void> _call(Customer c) async {
    final uri = Uri(scheme: 'tel', path: Customer.normalizePhone(c.phone));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _service.recordCall(c.phone, name: c.name);
    }
  }

  Future<void> _copy(Customer c) async {
    await Clipboard.setData(ClipboardData(text: Customer.normalizePhone(c.phone)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شماره کپی شد'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _done(Customer c) async {
    await _service.update(c.copyWith(clearReminder: true));
    _load();
  }

  Widget _card(Customer c, {bool overdue = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CustomerAvatar(name: c.name, tag: c.tag, size: 44),
        title: Text(c.name),
        subtitle: Text(
          '${overdue ? "عقب‌افتاده · " : ""}${Jalali.format(c.reminderAt!, withTime: true)} · ${c.status}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.copy_rounded, size: 20), onPressed: () => _copy(c)),
            IconButton(icon: Icon(Icons.phone_rounded, color: AppColors.accent), onPressed: () => _call(c)),
            IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () => _done(c)),
          ],
        ),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: c)));
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return Scaffold(
      appBar: AppBar(title: const Text('امروز زنگ بزن')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_due.isEmpty && _up.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('یادآوری‌ای نیست', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('از صفحه مشتری → یادآوری تماس تنظیم کنید', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_due.isNotEmpty) ...[
                      Text('امروز و عقب‌افتاده', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._due.map((c) {
                        final rd = DateTime(c.reminderAt!.year, c.reminderAt!.month, c.reminderAt!.day);
                        return _card(c, overdue: rd.isBefore(start));
                      }),
                    ],
                    if (_up.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('روزهای آینده', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._up.map((c) => _card(c)),
                    ],
                  ],
                ),
    );
  }
}
