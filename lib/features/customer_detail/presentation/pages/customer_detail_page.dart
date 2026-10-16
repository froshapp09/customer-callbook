import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';

class CustomerDetailPage extends StatelessWidget {
  final String name;
  final String phone;
  final int callCount;

  const CustomerDetailPage({
    super.key,
    required this.name,
    required this.phone,
    required this.callCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات مشتری'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                name.characters.first,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              phone,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone),
                    label: const Text('تماس'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('ویرایش'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _InfoBox(title: 'تعداد تماس', value: '$callCount'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoBox(title: 'اولین تماس', value: '۱۴۰۳/۰۶/۱۲'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoBox(title: 'آخرین تماس', value: 'امروز'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'تاریخچه تماس‌ها',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      index % 2 == 0 ? Icons.call_received : Icons.call_made,
                      color: index % 2 == 0
                          ? AppColors.success
                          : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            index % 2 == 0 ? 'تماس ورودی' : 'تماس خروجی',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '۱۴۰۳/۰۶/${12 - index}  |  ۱۴:۳۰',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '۰${index + 2}:${30 + index * 5}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }),
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
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
