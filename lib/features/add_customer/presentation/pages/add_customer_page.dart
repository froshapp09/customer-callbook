import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';

class AddCustomerPage extends StatefulWidget {
  final Customer? editCustomer;
  final String? initialPhone;

  const AddCustomerPage({super.key, this.editCustomer, this.initialPhone});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerService();
  bool _saving = false;

  bool get isEdit => widget.editCustomer != null;

  @override
  void initState() {
    super.initState();
    if (widget.editCustomer != null) {
      _nameCtrl.text = widget.editCustomer!.name;
      _phoneCtrl.text = widget.editCustomer!.phone;
      _noteCtrl.text = widget.editCustomer!.note ?? '';
    } else if (widget.initialPhone != null) {
      _phoneCtrl.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupName() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 7) return;
    final name = await _service.lookupNameFromDeviceContacts(phone);
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _nameCtrl.text = name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('نام از مخاطبین پیدا شد: $name'), backgroundColor: AppColors.success),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('در مخاطبین گوشی پیدا نشد')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (isEdit) {
        final updated = widget.editCustomer!.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        await _service.update(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مشتری ویرایش شد'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, updated);
        }
      } else {
        final customer = Customer(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        await _service.add(customer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مشتری ذخیره شد'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'ویرایش مشتری' : 'افزودن مشتری جدید'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text('نام و نام خانوادگی', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'نام کامل مشتری',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'نام الزامی است' : null,
              ),
              const SizedBox(height: 20),
              Text('شماره تلفن', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '09xxxxxxxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'شماره تلفن الزامی است';
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'شماره معتبر نیست';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _lookupName,
                  icon: const Icon(Icons.contact_phone_outlined, size: 18),
                  label: const Text('دریافت نام از مخاطبین گوشی'),
                ),
              ),
              const SizedBox(height: 12),
              Text('یادداشت (اختیاری)', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'یادداشت...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                    : const Icon(Icons.check),
                label: Text(isEdit ? 'ذخیره تغییرات' : 'ذخیره'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
