import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer_callbook/core/theme/app_theme.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/core/theme/theme_controller.dart';
import 'package:customer_callbook/core/theme/tag_colors.dart';
import 'package:customer_callbook/data/services/contact_cache.dart';
import 'package:customer_callbook/features/home/presentation/pages/home_page.dart';

class CustomerCallbookApp extends StatefulWidget {
  const CustomerCallbookApp({super.key});

  @override
  State<CustomerCallbookApp> createState() => _CustomerCallbookAppState();
}

class _CustomerCallbookAppState extends State<CustomerCallbookApp> {
  final _theme = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    _init();
    _theme.addListener(_onTheme);
  }

  Future<void> _init() async {
    await _theme.load();
    await TagColors.instance.load();
    ContactCache.instance.warmUp(); // background, don't wait
    if (mounted) setState(() {});
  }

  void _onTheme() {
    AppColors.isDark = _theme.isDark;
    _applySystemUi(_theme.isDark);
    if (mounted) setState(() {});
  }

  void _applySystemUi(bool dark) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: dark ? const Color(0xFF1A1B2E) : const Color(0xFFE8ECF8),
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _theme.removeListener(_onTheme);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.isDark = _theme.isDark;
    return MaterialApp(
      title: 'دفترچه مشتریان',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _theme.isDark ? ThemeMode.dark : ThemeMode.light,
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
