import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/core/theme/theme_controller.dart';
import 'package:customer_callbook/core/theme/tag_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/phonebook/presentation/pages/phonebook_page.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';
import 'package:customer_callbook/features/call_sync/presentation/pages/call_sync_page.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
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
    final list = await _service.getAll();
    if (mounted) setState(() { _customers = list; _loading = false; });
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
    final now = DateTime.now();
    return _customers.where((c) {
      final d = c.lastCallAt;
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
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
              PhonebookPage(onChanged: _load),
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
            onTap: (i) => setState(() => _tab = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.phone_outlined), activeIcon: Icon(Icons.phone_rounded), label: 'تماس‌ها'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people_rounded), label: 'مشتریان'),
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
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'همین الان';
    if (d.inMinutes < 60) return '${d.inMinutes} دقیقه پیش';
    if (d.inHours < 24) return '${d.inHours} ساعت پیش';
    if (d.inDays == 1) return 'دیروز';
    return '${d.inDays} روز پیش';
  }

  Color _avatarColor(String name) {
    final p = AppColors.avatarPalette;
    return p[name.hashCode.abs() % p.length];
  }

  @override
  Widget build(BuildContext context) {
    final recent = customers.where((c) => c.lastCallAt != null).toList()
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
        color: AppColors.surfaceElevated.withOpacity(AppColors.isDark ? 0.85 : 0.92),
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
        _ThemeTile(),
        const SizedBox(height: 10),
        _tile(context, Icons.phone_android_rounded, AppColors.primary, 'تماس‌های گوشی', 'خواندن تاریخچه و افزودن', () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CallSyncPage()));
          onReload();
        }),
        _tile(context, Icons.shield_rounded, AppColors.info, 'مجوزهای برنامه', 'تلفن، مخاطبین، پیامک', () => openAppSettings()),
        _tile(context, Icons.palette_rounded, AppColors.warning, 'رنگ دسته‌بندی‌ها', 'مشتری، همکار، سایر', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _TagColorPage()));
        }),
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
        _tile(context, Icons.info_rounded, AppColors.textMuted, 'درباره برنامه', 'نسخه ۱.۱۰.۰ — دفترچه مشتریان', null),
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

class _ThemeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    return AnimatedBuilder(
      animation: theme,
      builder: (context, _) {
        return _GlassCard(
          child: Row(
            children: [
              Switch(value: theme.isDark, onChanged: (v) => theme.setDark(v)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(theme.isDark ? 'حالت تیره' : 'حالت روشن', style: Theme.of(context).textTheme.titleMedium),
                    Text('فعال‌سازی حالت تیره در برنامه', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Icon(theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        );
      },
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
                      final selected = c.value == color.value;
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
