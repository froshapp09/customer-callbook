import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/services/customer_service.dart';
import 'package:customer_callbook/data/services/note_templates_service.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final _customers = CustomerService();

  Future<String> exportJson() async {
    final list = await _customers.getAll();
    final templates = await NoteTemplatesService.instance.getAll();
    final map = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': list.map((c) => c.toJson()).toList(),
      'noteTemplates': templates,
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<String> exportCsv() async {
    final list = await _customers.getAll();
    final buf = StringBuffer('name,phone,tag,note,callCount,favorite\n');
    for (final c in list) {
      final note = (c.note ?? '').replaceAll('"', '""').replaceAll('\n', ' ');
      buf.writeln('"${c.name}","${c.phone}","${c.tag}","$note",${c.callCount},${c.favorite}');
    }
    return buf.toString();
  }

  /// بازگردانی از JSON پشتیبان — شماره‌های تکراری به‌روز می‌شوند
  Future<int> importJson(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map) throw Exception('فرمت نامعتبر');
    final list = data['customers'];
    if (list is! List) throw Exception('لیست مشتری نیست');
    int n = 0;
    for (final e in list) {
      if (e is! Map) continue;
      final c = Customer.fromJson(Map<String, dynamic>.from(e));
      final existing = await _customers.findByPhone(c.phone);
      if (existing == null) {
        await _customers.add(c);
      } else {
        await _customers.update(existing.copyWith(
          name: c.name,
          note: c.note,
          tag: c.tag,
          favorite: c.favorite,
        ));
      }
      n++;
    }
    final tpls = data['noteTemplates'];
    if (tpls is List && tpls.isNotEmpty) {
      await NoteTemplatesService.instance.saveAll(tpls.map((e) => e.toString()).toList());
    }
    return n;
  }
}
