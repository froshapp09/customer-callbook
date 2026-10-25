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
  List<Customer> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.remindersDueToday();
    if (mounted) setState(() { _list = list; _loading = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('امروز زنگ بزن')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('یادآوری برای امروز نیست', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _list.length,
                  itemBuilder: (context, i) {
                    final c = _list[i];
                    final overdue = c.reminderAt!.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CustomerAvatar(name: c.name, tag: c.tag, size: 44),
                        title: Text(c.name),
                        subtitle: Text(
                          '${overdue ? "عقب‌افتاده · " : ""}${Jalali.format(c.reminderAt!)} · ${c.status}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.copy_rounded, size: 20), onPressed: () => _copy(c), tooltip: 'کپی'),
                            IconButton(icon: Icon(Icons.phone_rounded, color: AppColors.accent), onPressed: () => _call(c)),
                            IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () => _done(c), tooltip: 'انجام شد'),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: c)));
                          _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
