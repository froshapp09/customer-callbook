import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_callbook/data/models/customer.dart';

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
    try {
      return list.firstWhere(
        (e) => e.phone.replaceAll(RegExp(r'\D'), '').endsWith(cleaned) ||
            cleaned.endsWith(e.phone.replaceAll(RegExp(r'\D'), '')),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> recordCall(String phone, {String? name}) async {
    final existing = await findByPhone(phone);
    if (existing != null) {
      final updated = existing.copyWith(
        callCount: existing.callCount + 1,
        lastCallAt: DateTime.now(),
        firstCallAt: existing.firstCallAt ?? DateTime.now(),
      );
      await update(updated);
    } else if (name != null && name.isNotEmpty) {
      await add(Customer(
        name: name,
        phone: phone,
        callCount: 1,
        firstCallAt: DateTime.now(),
        lastCallAt: DateTime.now(),
      ));
    }
  }
}
