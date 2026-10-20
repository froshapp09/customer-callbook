import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/core/utils/jalali.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final _service = CustomerService();
  bool _loading = true;
  int _calls = 0;
  int _newCustomers = 0;
  int _noAnswer = 0;
  int _purchased = 0;
  int _negotiating = 0;
  int _vip = 0;
  double _orderSum = 0;

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

    final calls = history.where((r) => r.at.isAfter(weekAgo)).length;
    final neu = customers.where((c) => c.createdAt.isAfter(weekAgo)).length;
    final noAns = customers.where((c) => c.status == CustomerStatus.noAnswer).length;
    final bought = customers.where((c) => c.status == CustomerStatus.purchased).length;
    final neg = customers.where((c) => c.status == CustomerStatus.negotiating).length;
    final vip = customers.where((c) => c.favorite).length;
    double sum = 0;
    for (final c in customers) {
      if (c.orderAmount != null) sum += c.orderAmount!;
    }

    if (mounted) {
      setState(() {
        _calls = calls;
        _newCustomers = neu;
        _noAnswer = noAns;
        _purchased = bought;
        _negotiating = neg;
        _vip = vip;
        _orderSum = sum;
        _loading = false;
      });
    }
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
                const SizedBox(height: 20),
                _row(Icons.phone_in_talk_rounded, AppColors.primary, 'تماس این هفته', '$_calls'),
                _row(Icons.person_add_rounded, AppColors.info, 'مشتری جدید', '$_newCustomers'),
                _row(Icons.hourglass_empty_rounded, AppColors.warning, 'در حال مذاکره', '$_negotiating'),
                _row(Icons.shopping_bag_rounded, AppColors.success, 'خرید کرده', '$_purchased'),
                _row(Icons.phone_missed_rounded, AppColors.danger, 'بی‌پاسخ', '$_noAnswer'),
                _row(Icons.star_rounded, const Color(0xFFF59E0B), 'VIP', '$_vip'),
                _row(Icons.payments_rounded, AppColors.primary, 'جمع مبلغ سفارش‌ها',
                    _orderSum > 0 ? '${_orderSum.toStringAsFixed(0)} تومان' : '—'),
              ],
            ),
    );
  }

  Widget _row(IconData icon, Color color, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
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
