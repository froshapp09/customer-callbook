import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/core/utils/jalali.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});
  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final _service = CustomerService();
  bool _loading = true;
  int _calls = 0, _in = 0, _out = 0, _miss = 0;
  int _newCustomers = 0, _noAnswer = 0, _purchased = 0, _negotiating = 0, _vip = 0;
  double _orderSum = 0;
  List<Customer> _newList = [];
  List<Customer> _bought = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    await _service.dedupeCallHistory();
    final history = await _service.getCallHistory(limit: 500);
    final customers = await _service.getAll();
    final weekCalls = history.where((r) => r.at.isAfter(weekAgo)).toList();
    final neu = customers.where((c) => c.createdAt.isAfter(weekAgo)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final bought = customers.where((c) => c.status == CustomerStatus.purchased).toList();

    if (!mounted) return;
    setState(() {
      _calls = weekCalls.length;
      _in = weekCalls.where((r) => r.type == 1).length;
      _out = weekCalls.where((r) => r.type == 2).length;
      _miss = weekCalls.where((r) => r.type == 3).length;
      _newCustomers = neu.length;
      _newList = neu.take(10).toList();
      _negotiating = customers.where((c) => c.status == CustomerStatus.negotiating).length;
      _purchased = bought.length;
      _bought = bought.take(8).toList();
      _noAnswer = customers.where((c) => c.status == CustomerStatus.noAnswer).length;
      _vip = customers.where((c) => c.callCount >= 5 || c.favorite).length;
      _orderSum = customers.fold(0.0, (s, c) => s + (c.orderAmount ?? 0));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('گزارش هفتگی')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'از ${Jalali.format(DateTime.now().subtract(const Duration(days: 7)))} تا امروز',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('تماس‌ها', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _row(Icons.phone_in_talk_rounded, AppColors.primary, 'کل تماس این هفته', '$_calls'),
                _row(Icons.call_received_rounded, AppColors.accent, 'ورودی', '$_in'),
                _row(Icons.call_made_rounded, AppColors.info, 'خروجی', '$_out'),
                _row(Icons.call_missed_rounded, AppColors.danger, 'از دست‌رفته', '$_miss'),
                const SizedBox(height: 12),
                Text('فروش و مشتری', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _row(Icons.person_add_rounded, AppColors.info, 'مشتری جدید این هفته', '$_newCustomers'),
                _row(Icons.hourglass_empty_rounded, AppColors.warning, 'در حال مذاکره', '$_negotiating'),
                _row(Icons.shopping_bag_rounded, AppColors.success, 'خرید کرده', '$_purchased'),
                _row(Icons.phone_missed_rounded, AppColors.danger, 'بی‌پاسخ', '$_noAnswer'),
                _row(Icons.star_rounded, const Color(0xFFF59E0B), 'VIP / ویژه', '$_vip'),
                _row(Icons.payments_rounded, AppColors.primary, 'جمع مبلغ سفارش‌ها',
                    _orderSum > 0 ? '${_orderSum.toStringAsFixed(0)} تومان' : '—'),
                if (_newList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('مشتریان جدید', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._newList.map((c) => ListTile(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text(Customer.displayPhone(c.phone), textDirection: TextDirection.ltr),
                        trailing: Text(c.status, style: TextStyle(fontSize: 12, color: Color(CustomerStatus.colorValue(c.status)))),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: c))),
                      )),
                ],
                if (_bought.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('خرید کرده‌ها', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._bought.map((c) => ListTile(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text(c.orderAmount != null ? '${c.orderAmount!.toStringAsFixed(0)} تومان' : c.city ?? ''),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: c))),
                      )),
                ],
              ],
            ),
    );
  }

  Widget _row(IconData icon, Color color, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        ],
      ),
    );
  }
}
