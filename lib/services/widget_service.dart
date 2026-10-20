import 'package:home_widget/home_widget.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/models/customer.dart';

class WidgetService {
  static final instance = WidgetService._();
  WidgetService._();

  static const androidName = 'DaftarcheWidgetProvider';

  Future<void> update() async {
    try {
      final service = CustomerService();
      final customers = await service.getAll();
      final now = DateTime.now();
      final today = customers.where((c) {
        final d = c.lastCallAt;
        if (d == null || c.callCount <= 0) return false;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList()
        ..sort((a, b) => b.lastCallAt!.compareTo(a.lastCallAt!));

      final lines = today.take(3).map((c) {
        final t = c.lastCallAt!;
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        return '$hh:$mm  ${c.name}  ${Customer.displayPhone(c.phone)}';
      }).toList();

      await HomeWidget.saveWidgetData<String>('widget_count', '${today.length}');
      await HomeWidget.saveWidgetData<String>(
        'widget_line1',
        lines.isNotEmpty ? lines[0] : 'تماس امروزی ثبت نشده',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_line2',
        lines.length > 1 ? lines[1] : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_line3',
        lines.length > 2 ? lines[2] : '',
      );
      await HomeWidget.updateWidget(androidName: androidName);
    } catch (_) {
      // ویجت اختیاری است؛ خطا نباید اپ را بشکند
    }
  }
}
