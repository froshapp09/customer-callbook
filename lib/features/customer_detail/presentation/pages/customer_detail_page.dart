import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';

class CustomerDetailPage extends StatefulWidget {
  final Customer customer;
  const CustomerDetailPage({super.key, required this.customer});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Customer _customer;
  final _service = CustomerService();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _noteCtrl.text = _customer.note ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _mobile => Customer.isMobile(_customer.phone);

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: Customer.normalizePhone(_customer.phone));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      final u = await _service.recordCall(_customer.phone, name: _customer.name);
      setState(() => _customer = u);
    }
  }

  Future<void> _sms() async {
    if (!_mobile) return;
    final uri = Uri(scheme: 'sms', path: Customer.normalizePhone(_customer.phone));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    if (!_mobile) return;
    final uri = Uri.parse('https://wa.me/${Customer.toWhatsAppNumber(_customer.phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: Customer.normalizePhone(_customer.phone)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شماره کپی شد'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final u = _customer.copyWith(favorite: !_customer.favorite);
    await _service.update(u);
    setState(() => _customer = u);
  }

  Future<void> _edit() async {
    final r = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => AddCustomerPage(editCustomer: _customer)),
    );
    if (r != null) {
      setState(() {
        _customer = r;
        _noteCtrl.text = r.note ?? '';
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مشتری؟'),
        content: Text('«${_customer.name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await _service.delete(_customer.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _saveNote() async {
    final u = _customer.copyWith(note: _noteCtrl.text.trim());
    await _service.update(u);
    setState(() => _customer = u);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('یادداشت ذخیره شد'), backgroundColor: AppColors.success),
      );
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '—';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes} دقیقه پیش';
    if (d.inHours < 24) return '${d.inHours} ساعت پیش';
    if (d.inDays < 7) return '${d.inDays} روز پیش';
    return _fmt(dt);
  }

  Color _avatarColor(String name) {
    final colors = [AppColors.avatar1, AppColors.avatar2, AppColors.avatar3, AppColors.avatar4];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = Customer.phoneTypeLabel(_customer.phone);
    final isVip = _customer.callCount >= 5;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_customer.favorite ? Icons.star : Icons.star_border, color: _customer.favorite ? AppColors.warning : null),
            onPressed: _toggleFavorite,
            tooltip: 'ویژه',
          ),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: _avatarColor(_customer.name),
              child: Text(
                _customer.name.isNotEmpty ? _customer.name.characters.first : '?',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_customer.favorite) ...[
                  const Icon(Icons.star, color: AppColors.warning, size: 18),
                  const SizedBox(width: 4),
                ],
                Flexible(child: Text(_customer.name, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _Chip(label: _customer.tag, color: AppColors.primary),
                _Chip(label: typeLabel, color: _mobile ? AppColors.accent : AppColors.textMuted),
                if (isVip) const _Chip(label: 'پرتردد', color: AppColors.warning),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onLongPress: _copy,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Customer.displayPhone(_customer.phone),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.textMuted),
                    onPressed: _copy,
                    tooltip: 'کپی شماره',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // اکشن‌ها — پیامک/واتساپ فقط موبایل
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(icon: Icons.phone, label: 'تماس', color: AppColors.accent, onTap: _call),
                if (_mobile) _ActionBtn(icon: Icons.sms_outlined, label: 'پیامک', color: AppColors.info, onTap: _sms),
                if (_mobile) _ActionBtn(icon: Icons.chat, label: 'واتساپ', color: const Color(0xFF25D366), onTap: _whatsapp),
                _ActionBtn(icon: Icons.edit_outlined, label: 'ویرایش', color: AppColors.primary, onTap: _edit),
              ],
            ),
            if (!_mobile) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'این شماره موبایل نیست؛ پیامک و واتساپ فقط برای موبایل فعال است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(child: _InfoCol(title: 'تعداد تماس', value: '${_customer.callCount}')),
                  Expanded(child: _InfoCol(title: 'آخرین تماس', value: _timeAgo(_customer.lastCallAt))),
                  Expanded(child: _InfoCol(title: 'اولین تماس', value: _fmt(_customer.firstCallAt))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text('یادداشت', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'یادداشت فروش، پیگیری سفارش...'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _saveNote, child: const Text('ذخیره یادداشت')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 56, height: 56, child: Icon(icon, color: color)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _InfoCol extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCol({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
