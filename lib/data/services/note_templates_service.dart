import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_callbook/core/utils/text_repair.dart';

class NoteTemplatesService {
  static final NoteTemplatesService instance = NoteTemplatesService._();
  NoteTemplatesService._();

  static const _key = 'note_templates_v1';
  static const defaults = [
    'پیگیری سفارش',
    'علاقه‌مند به خرید',
    'نیاز به مشاوره',
    'ارسال کاتالوگ',
    'تماس مجدد فردا',
  ];

  Future<List<String>> getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      await saveAll(List.from(defaults));
      return List.from(defaults);
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => TextRepair.fix(e.toString()))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final stillBroken = list.where(TextRepair.looksBroken).length;
      if (list.isEmpty || stillBroken > 0) {
        await saveAll(List.from(defaults));
        return List.from(defaults);
      }
      // persist repaired version
      final original = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      if (list.join('|') != original.join('|')) {
        await saveAll(list);
      }
      return list;
    } catch (_) {
      await saveAll(List.from(defaults));
      return List.from(defaults);
    }
  }

  Future<void> saveAll(List<String> items) async {
    final p = await SharedPreferences.getInstance();
    final clean = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await p.setString(_key, jsonEncode(clean));
  }

  Future<void> add(String text) async {
    final list = await getAll();
    final t = TextRepair.fix(text.trim());
    if (t.isEmpty || TextRepair.looksBroken(t)) return;
    if (!list.contains(t)) list.add(t);
    await saveAll(list);
  }

  Future<void> remove(String text) async {
    final list = await getAll();
    list.remove(text);
    await saveAll(list);
  }
}
