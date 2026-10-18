import 'package:flutter/material.dart';
import 'package:customer_callbook/core/theme/app_theme.dart';
import 'package:customer_callbook/features/home/presentation/pages/home_page.dart';

class CustomerCallbookApp extends StatelessWidget {
  const CustomerCallbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفترچه مشتریان',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomePage(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}
