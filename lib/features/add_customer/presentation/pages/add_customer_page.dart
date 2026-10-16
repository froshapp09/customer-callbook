import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';

class AddCustomerPage extends StatefulWidget {
  final String? initialPhone;

  const AddCustomerPage({super.key, this.initialPhone});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('افزودن مشتری جدید'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'نام و نام خانوادگی',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'نام کامل مشتری را وارد کنید',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'نام الزامی است';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'شماره تلفن',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '09xxxxxxxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'شماره تلفن الزامی است';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'یادداشت (اختیاری)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'یادداشت خود را اینجا وارد کنید...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // بعداً ذخیره در Hive اضافه می‌شود
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('مشتری با موفقیت ذخیره شد'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('ذخیره'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'اطلاعات مشتری پس از ذخیره در لیست مشتریان قابل مشاهده است.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
