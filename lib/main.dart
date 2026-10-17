import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer_callbook/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF09090B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CustomerCallbookApp());
}
