import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/features/add_customer/presentation/pages/add_customer_page.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: _customer.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      final updated = _customer.copyWith(
        callCount: _customer.callCount + 1,
        lastCallAt: DateTime.now(),
        firstCallAt: _customer.firstCallAt ?? DateTime.now(),
      );
      await _service.update(updated);
      setState(() => _customer = updated);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان برقراری تماس وجود ندارد')),
      );
    }
  }

  Future<void> _sms() async {
    final uri = Uri(scheme: 'sms', path: _customer.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان ارسال پیامک وجود ندارد')),
      );
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerPage(editCustomer: _customer),
      ),
    );
    if (result != null) {
      setState(() {
        _customer = result;
        _noteCtrl.text = result.note ?? '';
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف مشتری؟'),
        content: Text('«${_customer.name}» حذف شود؟'),
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
      await _service.delete(_customer.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _saveNote() async {
    final updated = _customer.copyWith(note: _noteCtrl.text.trim());
    await _service.update(updated);
    setState(() => _customer = updated);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات مشتری'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surfaceLight,
              child: Text(
                _customer.name.isNotEmpty ? _customer.name.characters.first : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_customer.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              _customer.phone,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),

            // دکمه‌ها — عمودی تا متن نشکند
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _call,
                icon: const Icon(Icons.phone),
                label: const Text('تماس'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sms,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('پیامک'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('ویرایش'),
              ),
            ),

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: _InfoBox(title: 'تعداد تماس', value: '${_customer.callCount}')),
                const SizedBox(width: 12),
                Expanded(child: _InfoBox(title: 'اولین تماس', value: _fmt(_customer.firstCallAt))),
                const SizedBox(width: 12),
                Expanded(child: _InfoBox(title: 'آخرین تماس', value: _fmt(_customer.lastCallAt))),
              ],
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: Text('یادداشت', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'یادداشت خود را بنویسید...'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saveNote,
                child: const Text('ذخیره یادداشت'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
