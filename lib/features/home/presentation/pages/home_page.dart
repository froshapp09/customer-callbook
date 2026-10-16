import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/phonebook/presentation/pages/phonebook_page.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer_callbook/services/call_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _service = CustomerService();
  List<Customer> _customers = [];
  bool _loading = true;

  final _callListener = CallListenerService();

  @override
  void initState() {
    super.initState();
    _load();
    // شروع تشخیص تماس بعد از ساخته شدن ویجت
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _callListener.startListening(context);
    });
  }

  @override
  void dispose() {
    _callListener.stopListening();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getAll();
    setState(() {
      _customers = list;
      _loading = false;
    });
  }

  int get _todayCount {
    final now = DateTime.now();
    return _customers.where((c) {
      if (c.lastCallAt == null) return false;
      return c.lastCallAt!.year == now.year &&
          c.lastCallAt!.month == now.month &&
          c.lastCallAt!.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboard(),
            PhonebookPage(onChanged: _load),
            _buildSettings(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            if (i == 0 || i == 1) _load();
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_outlined),
              activeIcon: Icon(Icons.phone),
              label: 'تماس‌ها',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'مشتریان',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'تنظیمات',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCustomerPage()),
                );
                _load();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDashboard() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('دفترچه مشتریان', style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: _StatCard(title: 'تماس امروز', value: '$_todayCount', icon: Icons.phone_in_talk_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(title: 'مشتریان', value: '${_customers.length}', icon: Icons.people_outline)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'جدید',
                      value: '${_customers.where((c) => c.callCount <= 1).length}',
                      icon: Icons.person_add_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('آخرین تماس‌ها', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          if (_customers.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'هنوز مشتریی ثبت نشده\nاز تب مشتریان، مشتری جدید اضافه کنید',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final c = _customers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailPage(customer: c),
                          ),
                        );
                        _load();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.surfaceLight,
                              child: Text(
                                c.name.isNotEmpty ? c.name.characters.first : '?',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(c.phone, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${c.callCount} تماس',
                                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatTime(c.lastCallAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _customers.length > 20 ? 20 : _customers.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('تنظیمات', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        _SettingsTile(
          icon: Icons.phone_callback_outlined,
          title: 'فعال‌سازی تشخیص تماس',
          subtitle: 'مجوز تماس و نمایش پاپ‌آپ هنگام زنگ خوردن',
          onTap: () async {
            final ok = await _callListener.requestPermissions();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'مجوز داده شد - تشخیص تماس فعال است' : 'مجوز داده نشد. از تنظیمات گوشی فعال کنید'),
                backgroundColor: ok ? AppColors.success : AppColors.warning,
              ),
            );
            if (ok) {
              await _callListener.startListening(context);
            } else {
              openAppSettings();
            }
          },
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.delete_outline,
          title: 'پاک کردن همه مشتریان',
          subtitle: 'تمام اطلاعات حذف می‌شود',
          color: AppColors.danger,
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('حذف همه؟'),
                content: const Text('این عمل قابل بازگشت نیست.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await _service.saveAll([]);
              _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('همه مشتریان حذف شدند'), backgroundColor: AppColors.danger),
                );
              }
            }
          },
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.info_outline,
          title: 'درباره برنامه',
          subtitle: 'نسخه ۱.۰.۰ - دفترچه مشتریان هوشمند',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'دفترچه مشتریان',
              applicationVersion: '1.0.0',
              applicationLegalese: 'مدیریت تماس و مشتریان',
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    if (diff.inDays == 1) return 'دیروز';
    if (diff.inDays < 7) return '${diff.inDays} روز پیش';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: AppColors.surface,
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(title, style: TextStyle(color: color ?? AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    );
  }
}
