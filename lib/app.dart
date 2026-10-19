import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer_callbook/core/theme/app_theme.dart';
import 'package:customer_callbook/core/theme/app_colors.dart';
import 'package:customer_callbook/core/theme/theme_controller.dart';
import 'package:customer_callbook/core/theme/tag_colors.dart';
import 'package:customer_callbook/data/services/contact_cache.dart';
import 'package:customer_callbook/features/home/presentation/pages/home_page.dart';
import 'package:customer_callbook/services/call_listener_service.dart';

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
    ContactCache.instance.warmUp();
    // بازیابی شنود تماس اگر کاربر فعال کرده
    CallListenerService.instance.restoreIfEnabled();
    _applySystemUi(_theme.isDark);
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
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: dark ? const Color(0xFF1E1F33) : const Color(0xFFFFFFFF),
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
    final dark = _theme.isDark;
    return MaterialApp(
      title: 'دفترچه مشتریان',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      // key اجباری: کل درخت UI با تعویض تم از نو ساخته شود
      home: HomePage(key: ValueKey<bool>(dark)),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
