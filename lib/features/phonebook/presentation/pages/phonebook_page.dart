import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/features/customer_detail/presentation/pages/customer_detail_page.dart';

class PhonebookPage extends StatelessWidget {
  const PhonebookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final customers = [
      {'name': 'علی رضایی', 'phone': '09123456789', 'count': 8},
      {'name': 'سارا محمدی', 'phone': '09351234567', 'count': 5},
      {'name': 'مهدی کریمی', 'phone': '09198765432', 'count': 3},
      {'name': 'نگین حسینی', 'phone': '09025558811', 'count': 7},
      {'name': 'رضا یوسفی', 'phone': '09217772233', 'count': 2},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'دفترچه تلفن',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'جستجوی مشتری...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final c = customers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerDetailPage(
                          name: c['name'] as String,
                          phone: c['phone'] as String,
                          callCount: c['count'] as int,
                        ),
                      ),
                    );
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
                          radius: 24,
                          backgroundColor: AppColors.surfaceLight,
                          child: Text(
                            (c['name'] as String).characters.first,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c['phone'] as String,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${c['count']} تماس',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
