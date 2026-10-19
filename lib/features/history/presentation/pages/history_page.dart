import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/core/utils/jalali.dart';
import 'package:customer_callbook/data/models/call_record.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _service = CustomerService();
  List<CallRecord> _all = [];
  Map<String, Customer> _byPhone = {};
  bool _loading = true;
  /// 0 week, 1 month, 2 year
  int _range = 0;

  static const _weekDays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _service.getCallHistory(limit: 300);
    final customers = await _service.getAll();
    final map = <String, Customer>{};
    for (final c in customers) {
      map[Customer.normalizePhone(c.phone)] = c;
    }
    if (mounted) {
      setState(() {
        _all = records;
        _byPhone = map;
        _loading = false;
      });
    }
  }

  DateTime get _fromDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case 1:
        return today.subtract(const Duration(days: 30));
      case 2:
        return today.subtract(const Duration(days: 365));
      default:
        // هفته شمسی: از شنبه
        final weekday = now.weekday; // Mon=1 .. Sun=7
        // شنبه در DateTime = 6
        final daysFromSat = (weekday == 7) ? 6 : (weekday % 7); // rough
        // بهتر: شنبه = روزی که weekday==6
        var d = today;
        while (d.weekday != 6) {
          d = d.subtract(const Duration(days: 1));
        }
        return d;
    }
  }

  List<CallRecord> get _filtered {
    final from = _fromDate;
    return _all.where((r) => !r.at.isBefore(from)).toList();
  }

  /// گروه‌بندی بر اساس روز هفته شمسی (شنبه=0)
  Map<String, List<CallRecord>> get _grouped {
    final map = {for (final d in _weekDays) d: <CallRecord>[]};
    for (final r in _filtered) {
      final name = _weekDays[_shamsiWeekIndex(r.at)];
      map[name]!.add(r);
    }
    // فقط روزهایی که تماس دارند + ترتیب شنبه→جمعه
    return {
      for (final d in _weekDays)
        if (map[d]!.isNotEmpty) d: map[d]!,
    };
  }

  /// ایندکس روز هفته شمسی: شنبه=0 ... جمعه=6
  int _shamsiWeekIndex(DateTime dt) {
    // DateTime: Mon=1 ... Sun=7
    // می‌خواهیم: Sat=0, Sun=1, Mon=2, ..., Fri=6
    switch (dt.weekday) {
      case DateTime.saturday:
        return 0;
      case DateTime.sunday:
        return 1;
      case DateTime.monday:
        return 2;
      case DateTime.tuesday:
        return 3;
      case DateTime.wednesday:
        return 4;
      case DateTime.thursday:
        return 5;
      case DateTime.friday:
        return 6;
      default:
        return 0;
    }
  }

  Future<void> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: Customer.normalizePhone(phone));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _service.recordCall(phone);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final grouped = _grouped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('سابقه', style: Theme.of(context).textTheme.headlineMedium),
                        Text('تماس‌ها بر اساس بازه و روز هفته', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // فیلتر بازه
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _RangeChip(label: 'هفته', selected: _range == 0, onTap: () => setState(() => _range = 0)),
                    _RangeChip(label: 'ماه', selected: _range == 1, onTap: () => setState(() => _range = 1)),
                    _RangeChip(label: 'سال', selected: _range == 2, onTap: () => setState(() => _range = 2)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // خلاصه
              Row(
                children: [
                  _MiniStat(label: 'تماس', value: '${filtered.length}'),
                  const SizedBox(width: 8),
                  _MiniStat(
                    label: 'ورودی',
                    value: '${filtered.where((e) => e.type == 1).length}',
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    label: 'خروجی',
                    value: '${filtered.where((e) => e.type == 2).length}',
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    label: 'از دست‌رفته',
                    value: '${filtered.where((e) => e.type == 3).length}',
                    color: AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text('در این بازه سابقه‌ای نیست', style: Theme.of(context).textTheme.bodyMedium),
                          Text('از «دریافت تماس‌های گوشی» سابقه بسازید', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: grouped.length,
                      itemBuilder: (context, i) {
                        final day = grouped.keys.elementAt(i);
                        final items = grouped[day]!;
                        return _DaySection(
                          dayName: day,
                          count: items.length,
                          children: items.map((r) {
                            final phone = Customer.normalizePhone(r.phone);
                            final customer = _byPhone[phone];
                            final name = customer?.name ?? phone;
                            return _HistoryTile(
                              name: name,
                              phone: r.phone,
                              record: r,
                              onCall: () => _dial(r.phone),
                              onOpen: customer == null
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: customer)),
                                      );
                                      _load();
                                    },
                            );
                          }).toList(),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c)),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String dayName;
  final int count;
  final List<Widget> children;
  const _DaySection({required this.dayName, required this.count, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dayName,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count تماس', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String name;
  final String phone;
  final CallRecord record;
  final VoidCallback onCall;
  final VoidCallback? onOpen;

  const _HistoryTile({
    required this.name,
    required this.phone,
    required this.record,
    required this.onCall,
    this.onOpen,
  });

  Color get _typeColor {
    switch (record.type) {
      case 1:
        return AppColors.accent;
      case 3:
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }

  IconData get _typeIcon {
    switch (record.type) {
      case 1:
        return Icons.call_received_rounded;
      case 3:
        return Icons.call_missed_rounded;
      default:
        return Icons.call_made_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceElevated.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onCall,
          onLongPress: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: onCall,
                  icon: Icon(Icons.phone_rounded, color: AppColors.accent, size: 20),
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent.withOpacity(0.12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        Customer.displayPhone(phone),
                        style: Theme.of(context).textTheme.bodySmall,
                        textDirection: TextDirection.ltr,
                      ),
                      Text(
                        '${record.typeLabel} · ${Jalali.format(record.at, withTime: true)}',
                        style: TextStyle(fontSize: 11, color: _typeColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
