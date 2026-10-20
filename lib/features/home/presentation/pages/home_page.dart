import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/core/theme/theme_controller.dart';
import 'package:customer_callbook/core/theme/tag_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/core/utils/jalali.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/phonebook/presentation/pages/phonebook_page.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';
import 'package:customer_callbook/features/call_sync/presentation/pages/call_sync_page.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';
import 'package:customer_callbook/features/history/presentation/pages/history_page.dart';
import 'package:customer_callbook/services/call_listener_service.dart';
import 'package:customer_callbook/data/services/note_templates_service.dart';
import 'package:customer_callbook/data/services/backup_service.dart';
import 'package:customer_callbook/features/report/presentation/pages/weekly_report_page.dart';
import 'package:customer_callbook/services/widget_service.dart';
import 'package:customer_callbook/services/widget_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  int _refreshToken = 0;
  final _service = CustomerService();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _autoImportRecent();
    } catch (_) {}
    final list = await _service.getAll();
    WidgetService.instance.update();
    if (mounted) {
      setState(() {
        _customers = list;
        _loading = false;
        _refreshToken++;
      });
    }
  }

  /// شناسایی تماس‌های اخیر برای مشتریان ثبت‌شده (بدون درخواست مجوز اضافه)
  Future<void> _autoImportRecent() async {
    try {
      final entries = await _service.fetchRecentDeviceCalls(days: 2, limit: 25);
      final seen = <String>{};
      for (final e in entries) {
        final phone = (e['number'] ?? '').toString().trim();
        if (phone.isEmpty) continue;
        final key = Customer.normalizePhone(phone);
        if (seen.contains(key)) continue;
        seen.add(key);
        final existing = await _service.findByPhone(phone);
        if (existing == null) continue;
        final typ = (e['type'] ?? '').toString().toLowerCase();
        final typeInt = typ.contains('miss') || typ.contains('reject')
            ? 3
            : (typ.contains('in') ? 1 : 2);
        final ts = e['timestamp'];
        final at = ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
        // اگر آخرین تماس اپ جدیدتر/برابر است، رد شو
        if (existing.lastCallAt != null && at != null && !at.isAfter(existing.lastCallAt!)) {
          continue;
        }
        await _service.recordCall(phone, name: existing.name, type: typeInt);
        if (at != null) {
          await _service.addCallRecord(phone: phone, customerId: existing.id, type: typeInt, at: at);
        }
      }
    } catch (_) {}
  }

  Future<void> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: Customer.normalizePhone(phone));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _service.recordCall(phone);
      _load();
    }
  }

    int get _todayCount {
    // فقط تماس‌هایی که از خود اپ زده/ثبت شده‌اند (lastCallAt + callCount>0)
    final now = DateTime.now();
    return _customers.where((c) {
      if (c.callCount <= 0) return false;
      final d = c.lastCallAt;
      if (d == null) return false;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.background, AppColors.backgroundEnd],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: [
              _CallsTab(
                customers: _customers,
                loading: _loading,
                todayCount: _todayCount,
                onRefresh: _load,
                onDial: _dial,
                onOpenDetail: (c) async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: c)));
                  _load();
                },
                onSync: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const CallSyncPage()));
                  _load();
                },
              ),
              PhonebookPage(onChanged: _load, refreshToken: _refreshToken),
              HistoryPage(refreshToken: _refreshToken),
              _SettingsTab(onReload: _load, customers: _customers),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.navBar,
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) {
              setState(() {
                _tab = i;
                if (i == 1 || i == 2) _refreshToken++;
              });
              if (i == 1 || i == 2) _load();
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.phone_outlined), activeIcon: Icon(Icons.phone_rounded), label: 'تماس‌ها'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people_rounded), label: 'مشتریان'),
              BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history_rounded), label: 'سابقه'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'تنظیمات'),
            ],
          ),
        ),
        floatingActionButton: _tab == 1
            ? FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerPage()));
                  _load();
                },
                child: const Icon(Icons.person_add_alt_1_rounded),
              )
            : null,
      ),
    );
  }
}

class _CallsTab extends StatelessWidget {
  final List<Customer> customers;
  final bool loading;
  final int todayCount;
  final VoidCallback onRefresh;
  final Future<void> Function(String) onDial;
  final Future<void> Function(Customer) onOpenDetail;
  final Future<void> Function() onSync;

  const _CallsTab({
    required this.customers,
    required this.loading,
    required this.todayCount,
    required this.onRefresh,
    required this.onDial,
    required this.onOpenDetail,
    required this.onSync,
  });

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    return Jalali.timeAgoOrJalali(dt);
  }

  Color _avatarColor(String name) {
    final p = AppColors.avatarPalette;
    return p[name.hashCode.abs() % p.length];
  }

  @override
  Widget build(BuildContext context) {
    final recent = customers.where((c) => c.lastCallAt != null && c.callCount > 0).toList()
      ..sort((a, b) => b.lastCallAt!.compareTo(a.lastCallAt!));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
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
                            Text('تماس‌ها', style: Theme.of(context).textTheme.headlineMedium),
                            Text('مدیریت تماس‌ها و مشتریان امروز', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      _GlowIcon(Icons.phone_rounded, AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.person_add_alt_1_rounded, iconColor: AppColors.accent, value: '${customers.length}', label: 'مشتریان')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.phone_callback_rounded, iconColor: AppColors.primary, value: '$todayCount', label: 'تماس امروز')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PrimaryAction(
                    icon: Icons.phone_android_rounded,
                    title: 'دریافت تماس‌های گوشی',
                    subtitle: 'برای افزودن به مشتریان / خروجی CSV',
                    onTap: onSync,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('آخرین تماس‌ها', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (loading)
            const _SliverLoading()
          else if (recent.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_disabled_rounded, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('هنوز تماسی ثبت نشده', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = recent[i];
                    final tagColor = TagColors.instance.of(c.tag);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GlassCard(
                        onTap: () => onDial(c.phone),
                        onLongPress: () => onOpenDetail(c),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textMuted),
                              onPressed: () => onOpenDetail(c),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text(
                                    Customer.displayPhone(c.phone),
                                    style: Theme.of(context).textTheme.bodySmall,
                                    textDirection: TextDirection.ltr,
                                  ),
                                  Text(_timeAgo(c.lastCallAt), style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: _avatarColor(c.name).withOpacity(0.25),
                              child: Text(
                                c.name.isNotEmpty ? c.name.characters.first : '?',
                                style: TextStyle(fontWeight: FontWeight.w800, color: _avatarColor(c.name), fontSize: 17),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 4,
                              height: 36,
                              decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(4)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: recent.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SliverLoading extends StatelessWidget {
  const _SliverLoading();
  @override
  Widget build(BuildContext context) => SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PrimaryAction({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.9)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _GlassCard({required this.child, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: child),
        ),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GlowIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  final VoidCallback onReload;
  final List<Customer> customers;
  const _SettingsTab({required this.onReload, required this.customers});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تنظیمات', style: Theme.of(context).textTheme.headlineMedium),
                  Text('مدیریت تنظیمات و امکانات برنامه', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            _GlowIcon(Icons.settings_rounded, AppColors.primary),
          ],
        ),
        const SizedBox(height: 20),
        const _CallDetectTile(),
        const SizedBox(height: 10),
        _tile(context, Icons.phone_android_rounded, AppColors.primary, 'تماس‌های گوشی', 'خواندن تاریخچه و افزودن', () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CallSyncPage()));
          onReload();
        }),
        _tile(context, Icons.shield_rounded, AppColors.info, 'مجوزهای برنامه', 'تلفن، مخاطبین، پیامک', () => openAppSettings()),
        _tile(context, Icons.palette_rounded, AppColors.warning, 'رنگ دسته‌بندی‌ها', 'مشتری، همکار، سایر', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _TagColorPage()));
        }),
        const SizedBox(height: 10),
        _tile(context, Icons.sticky_note_2_rounded, const Color(0xFF38BDF8), 'یادداشت‌های آماده', 'انتخاب سریع هنگام ذخیره مشتری', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _NoteTemplatesPage()));
        }),
        _tile(context, Icons.insights_rounded, const Color(0xFF8B5CF6), 'گزارش هفتگی', 'تماس، مشتری جدید، وضعیت فروش', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReportPage()));
        }),
        const SizedBox(height: 10),
        _tile(context, Icons.backup_rounded, const Color(0xFF34D399), 'پشتیبان شماره‌ها', 'ذخیره و بازیابی بعد از نصب مجدد', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _BackupPage(onDone: onReload)));
        }),
        const SizedBox(height: 10),
        _tile(context, Icons.upload_file_rounded, const Color(0xFFA78BFA), 'خروجی لیست مشتریان', 'CSV برای پنل پیامک', () async {
          if (customers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مشتری‌ای نیست')));
            return;
          }
          final buf = StringBuffer('نام,شماره,تگ,تعداد تماس\n');
          for (final c in customers) {
            buf.writeln('${c.name},${c.phone},${c.tag},${c.callCount}');
          }
          await Share.share(buf.toString(), subject: 'لیست مشتریان');
        }),
        _tile(context, Icons.info_rounded, AppColors.textMuted, 'درباره برنامه', 'نسخه ۱.۲۱.۰ (۳۸) — info@apadanasleep.ir', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _AboutPage()));
        }),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, Color color, String title, String sub, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            if (onTap != null) Icon(Icons.chevron_left, color: AppColors.textMuted),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(sub, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}


class _TagColorPage extends StatefulWidget {
  const _TagColorPage();
  @override
  State<_TagColorPage> createState() => _TagColorPageState();
}

class _TagColorPageState extends State<_TagColorPage> {
  @override
  Widget build(BuildContext context) {
    final tags = TagColors.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('رنگ دسته‌بندی‌ها')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: ['مشتری', 'همکار', 'سایر'].map((tag) {
          final color = tags.of(tag);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(tag, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: tags.palette.map((c) {
                      final selected = TagColors.instance.isSelected(tag, c);
                      return GestureDetector(
                        onTap: () async {
                          await tags.set(tag, c);
                          setState(() {});
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: selected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CallDetectTile extends StatefulWidget {
  const _CallDetectTile();
  @override
  State<_CallDetectTile> createState() => _CallDetectTileState();
}

class _CallDetectTileState extends State<_CallDetectTile> {
  bool _on = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    CallListenerService.instance.isEnabled().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _busy = true);
    try {
      if (v) {
        final ok = await CallListenerService.instance.enableAndStart();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مجوز تلفن لازم است. از تنظیمات مجوز بدهید.')),
          );
          await openAppSettings();
        }
        setState(() => _on = ok);
      } else {
        await CallListenerService.instance.disableAndStop();
        setState(() => _on = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          if (_busy)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch(value: _on, onChanged: _toggle),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('شناسایی تماس ورودی', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _on ? 'فعال — با تماس، اعلان نام مشتری می‌آید' : 'خاموش — برای اعلان هنگام تماس روشن کنید',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.75)]),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.ring_volume_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}


class _NoteTemplatesPage extends StatefulWidget {
  const _NoteTemplatesPage();
  @override
  State<_NoteTemplatesPage> createState() => _NoteTemplatesPageState();
}

class _NoteTemplatesPageState extends State<_NoteTemplatesPage> {
  List<String> _items = [];
  final _ctrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NoteTemplatesService.instance.getAll();
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await NoteTemplatesService.instance.add(text);
    _ctrl.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«$text» اضافه شد')));
    }
  }

  Future<void> _remove(String text) async {
    await NoteTemplatesService.instance.remove(text);
    await _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('یادداشت‌های آماده')),
      body: Column(
        children: [
          // ساخت یادداشت — همیشه بالای صفحه
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: AppColors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ساخت یادداشت جدید', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: 'مثلاً: ارسال فاکتور',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                      onPressed: _add,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن یادداشت'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(child: Text('هنوز یادداشتی نیست — بالا بسازید', style: Theme.of(context).textTheme.bodyMedium))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final e = _items[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(e),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.danger),
                                onPressed: () => _remove(e),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


class _BackupPage extends StatefulWidget {
  final VoidCallback onDone;
  const _BackupPage({required this.onDone});
  @override
  State<_BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<_BackupPage> {
  bool _busy = false;
  String? _msg;

  Future<void> _saveFile() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final json = await BackupService.instance.exportJson();
      const channel = MethodChannel('ir.apadanasleep.customer_callbook/call_log');
      final path = await channel.invokeMethod<String>('saveToDownloads', {
        'content': json,
        'fileName': 'daftarche_backup.json',
      });
      if (mounted) {
        setState(() => _msg =
            '✓ ذخیره مستقیم انجام شد\n'
            '📁 فایل‌ها → Download → Daftarche\n'
            '📄 daftarche_backup.json\n'
            '${path != null ? 'مسیر: $path' : ''}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پشتیبان در Download/Daftarche ذخیره شد')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _msg = 'خطا در ذخیره مستقیم: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadFile() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() { _busy = false; _msg = 'فایلی انتخاب نشد'; });
        return;
      }
      final f = result.files.first;
      String raw;
      if (f.bytes != null) {
        raw = String.fromCharCodes(f.bytes!);
      } else if (f.path != null) {
        raw = await File(f.path!).readAsString();
      } else {
        throw Exception('نتوانست فایل را بخواند');
      }
      final n = await BackupService.instance.importJson(raw);
      widget.onDone();
      if (mounted) {
        setState(() => _msg = '✓ $n مشتری از فایل بازیابی شد');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n مشتری بازیابی شد'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _msg = 'خطا در بازیابی: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبان شماره‌ها')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'ذخیره مستقیم (بدون اشتراک‌گذاری):\n'
              '📂 فایل‌ها → Download → Daftarche\n'
              '📄 daftarche_backup.json\n\n'
              '۱) ذخیره فایل پشتیبان را بزنید\n'
              '۲) بعد از نصب مجدد، انتخاب فایل و همین مسیر را باز کنید',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          Text('ذخیره', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _saveFile,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('ذخیره فایل پشتیبان'),
            ),
          ),
          const SizedBox(height: 28),
          Text('بازیابی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _loadFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('انتخاب فایل پشتیبان از گوشی'),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 20),
            Text(_msg!, style: TextStyle(color: AppColors.primary, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('درباره برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Icon(Icons.contacts_rounded, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('دفترچه مشتریان', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('نسخه ۱.۲۱.۰ (۳۸)', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.email_outlined, color: AppColors.primary),
            title: const Text('پشتیبانی و توسعه'),
            subtitle: const Text('info@apadanasleep.ir'),
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: 'info@apadanasleep.ir', queryParameters: {
                'subject': 'دفترچه مشتریان',
              });
              // ignore: deprecated_member_use
              try {
                await launchUrl(uri);
              } catch (_) {}
            },
          ),
          const SizedBox(height: 8),
          Text(
            'آپادانا اسلیپ',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
