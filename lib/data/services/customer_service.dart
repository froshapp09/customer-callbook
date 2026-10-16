import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class CustomerService {
  static const _key = 'customers_list';

  Future<List<Customer>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => Customer.fromJson(e)).toList()
      ..sort((a, b) {
        final aTime = a.lastCallAt ?? a.createdAt;
        final bTime = b.lastCallAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
  }

  Future<void> saveAll(List<Customer> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((e) => e.toJson()).toList();
    await prefs.setStringList(_key, raw);
  }

  Future<void> add(Customer customer) async {
    final list = await getAll();
    // جلوگیری از شماره تکراری
    final cleaned = customer.phone.replaceAll(RegExp(r'\D'), '');
    final exists = list.any((e) => e.phone.replaceAll(RegExp(r'\D'), '') == cleaned);
    if (exists) return;
    list.add(customer);
    await saveAll(list);
  }

  Future<void> update(Customer customer) async {
    final list = await getAll();
    final index = list.indexWhere((e) => e.id == customer.id);
    if (index != -1) {
      list[index] = customer;
      await saveAll(list);
    }
  }

  Future<void> delete(String id) async {
    final list = await getAll();
    list.removeWhere((e) => e.id == id);
    await saveAll(list);
  }

  Future<Customer?> findByPhone(String phone) async {
    final list = await getAll();
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return null;
    try {
      return list.firstWhere((e) {
        final p = e.phone.replaceAll(RegExp(r'\D'), '');
        return p == cleaned || p.endsWith(cleaned) || cleaned.endsWith(p);
      });
    } catch (_) {
      return null;
    }
  }

  /// فقط وقتی تماس واقعی رخ داده فراخوانی شود
  Future<void> recordCall(String phone, {String? name}) async {
    final existing = await findByPhone(phone);
    if (existing != null) {
      final updated = existing.copyWith(
        callCount: existing.callCount + 1,
        lastCallAt: DateTime.now(),
        firstCallAt: existing.firstCallAt ?? DateTime.now(),
      );
      await update(updated);
    } else {
      // مشتری جدید فقط اگر نام داشته باشیم از مخاطبین
      final displayName = name ?? await lookupNameFromDeviceContacts(phone);
      await add(Customer(
        name: displayName ?? phone,
        phone: phone,
        callCount: 1,
        firstCallAt: DateTime.now(),
        lastCallAt: DateTime.now(),
      ));
    }
  }

  /// دریافت نام از دفترچه تلفن گوشی (شیائومی/هواوی/سامسونگ)
  Future<String?> lookupNameFromDeviceContacts(String phone) async {
    try {
      final status = await Permission.contacts.status;
      if (!status.isGranted) {
        final req = await Permission.contacts.request();
        if (!req.isGranted) return null;
      }

      if (!await FlutterContacts.requestPermission(readonly: true)) {
        return null;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final cleaned = phone.replaceAll(RegExp(r'\D'), '');
      if (cleaned.length < 7) return null;

      for (final c in contacts) {
        for (final ph in c.phones) {
          final p = ph.number.replaceAll(RegExp(r'\D'), '');
          if (p == cleaned || p.endsWith(cleaned) || cleaned.endsWith(p)) {
            final name = c.displayName.trim();
            if (name.isNotEmpty) return name;
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }
}
