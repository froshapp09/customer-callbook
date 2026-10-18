import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/phonebook/presentation/pages/phonebook_page.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';
import 'package:customer_callbook/features/call_sync/presentation/pages/call_sync_page.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
    if (mounted) {
      setState(() {
        _customers = list;
        _loading = false;
      });
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

  int get _todayCount {
    final now = DateTime.now();
    return _customers.where((c) {
      if (c.lastCallAt == null) return false;
      final d = c.lastCallAt!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            PhonebookPage(
              onChanged: _load,
            ),
            _SettingsTab(onReload: _load, customers: _customers),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.phone_outlined), activeIcon: Icon(Icons.phone), label: 'تماس‌ها'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'مشتریان'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'تنظیمات'),
          ],
        ),
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerPage()));
                _load();
              },
              child: const Icon(Icons.person_add_alt_1),
            )
          : null,
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
    final colors = [AppColors.avatar1, AppColors.avatar2, AppColors.avatar3, AppColors.avatar4];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final recent = customers.where((c) => c.lastCallAt != null).toList()
      ..sort((a, b) => (b.lastCallAt!).compareTo(a.lastCallAt!));

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
                  Text('تماس‌ها', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('مخاطبین و تماس‌های اخیر', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _StatCard(value: '${customers.length}', label: 'مشتریان', icon: Icons.people_outline)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(value: '$todayCount', label: 'تماس امروز', icon: Icons.phone_callback_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(value: '${recent.length}', label: 'با تماس', icon: Icons.history)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onSync,
                      icon: const Icon(Icons.phone_android, color: AppColors.primary),
                      label: const Text('دریافت تماس‌های گوشی', style: TextStyle(color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        backgroundColor: AppColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('آخرین تماس‌ها', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (recent.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_disabled, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('هنوز تماسی ثبت نشده', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('از «دریافت تماس‌های گوشی» استفاده کنید', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          // کلیک = تماس
                          onTap: () => onDial(c.phone),
                          onLongPress: () => onOpenDetail(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // دکمه جزئیات
                                IconButton(
                                  icon: const Icon(Icons.info_outline, size: 20, color: AppColors.textMuted),
                                  onPressed: () => onOpenDetail(c),
                                  tooltip: 'جزئیات',
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(c.name, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.right),
                                      const SizedBox(height: 2),
                                      Text(
                                        Customer.displayPhone(c.phone),
                                        style: Theme.of(context).textTheme.bodySmall,
                                        textDirection: TextDirection.ltr,
                                      ),
                                      Text(_timeAgo(c.lastCallAt), style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: _avatarColor(c.name),
                                  child: Text(
                                    c.name.isNotEmpty ? c.name.characters.first : '?',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
          Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
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
        Text('تنظیمات', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        _tile(
          context,
          Icons.phone_android,
          'تماس‌های گوشی',
          'خواندن تاریخچه و افزودن به مشتریان',
          () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const CallSyncPage()));
            onReload();
          },
        ),
        _tile(context, Icons.security, 'مجوزهای برنامه', 'تلفن، مخاطبین، پیامک', () => openAppSettings()),
        _tile(
          context,
          Icons.upload_file_outlined,
          'خروجی لیست مشتریان',
          'برای پنل پیامک یا اکسل',
          () async {
            if (customers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مشتری‌ای نیست')));
              return;
            }
            final buf = StringBuffer('نام,شماره,تگ,تعداد تماس\n');
            for (final c in customers) {
              buf.writeln('${c.name},${c.phone},${c.tag},${c.callCount}');
            }
            await Share.share(buf.toString(), subject: 'لیست مشتریان');
          },
        ),
        _tile(context, Icons.info_outline, 'درباره', 'نسخه ۱.۶.۰ — دفترچه مشتریان', null),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(sub, style: Theme.of(context).textTheme.bodySmall),
          trailing: onTap != null ? const Icon(Icons.chevron_left, color: AppColors.textMuted) : null,
        ),
      ),
    );
  }
}
