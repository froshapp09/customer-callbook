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
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _service = CustomerService();
  String _tag = 'مشتری';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editCustomer != null) {
      _name.text = widget.editCustomer!.name;
      _phone.text = widget.editCustomer!.phone;
      _note.text = widget.editCustomer!.note ?? '';
      _tag = widget.editCustomer!.tag;
    } else if (widget.initialPhone != null) {
      _phone.text = Customer.normalizePhone(widget.initialPhone!);
      _service.lookupNameFromDeviceContacts(widget.initialPhone!).then((n) {
        if (n != null && mounted && _name.text.isEmpty) {
          setState(() => _name.text = n);
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = Customer.normalizePhone(_phone.text.trim());
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام و شماره الزامی است')));
      return;
    }
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره معتبر نیست')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.editCustomer != null) {
        final updated = widget.editCustomer!.copyWith(
          name: name,
          phone: phone,
          note: _note.text.trim(),
          tag: _tag,
        );
        await _service.update(updated);
        if (mounted) Navigator.pop(context, updated);
      } else {
        final c = Customer(name: name, phone: phone, note: _note.text.trim(), tag: _tag);
        final saved = await _service.add(c);
        if (mounted) Navigator.pop(context, saved);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editCustomer != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'ویرایش مشتری' : 'مشتری جدید')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'نام', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'شماره موبایل', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 14),
          Text('دسته‌بندی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['مشتری', 'همکار', 'سایر'].map((t) {
              final sel = _tag == t;
              return ChoiceChip(
                label: Text(t),
                selected: sel,
                onSelected: (_) => setState(() => _tag = t),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت', prefixIcon: Icon(Icons.notes_outlined))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(editing ? 'ذخیره تغییرات' : 'افزودن'),
          ),
        ],
      ),
    );
  }
}
