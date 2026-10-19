import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_callbook/data/services/contact_cache.dart';
import 'package:customer_callbook/data/models/customer.dart';
import 'package:customer_callbook/data/models/call_record.dart';
import 'package:uuid/uuid.dart';

class CustomerService {
  static const _key = 'customers_v2';

  Future<List<Customer>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Customer.fromJson(Map<String, dynamic>.from(e))).toList()
      ..sort((a, b) {
        final aT = a.lastCallAt ?? a.createdAt;
        final bT = b.lastCallAt ?? b.createdAt;
        return bT.compareTo(aT);
      });
  }

  Future<void> _save(List<Customer> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<Customer> add(Customer c) async {
    final all = await getAll();
    // جلوگیری از تکراری
    final norm = Customer.normalizePhone(c.phone);
    final idx = all.indexWhere((e) => Customer.normalizePhone(e.phone) == norm);
    if (idx >= 0) {
      final existing = all[idx];
      final updated = existing.copyWith(
        name: c.name.isNotEmpty && c.name != c.phone ? c.name : existing.name,
        callCount: existing.callCount + (c.callCount > 0 ? c.callCount : 0),
        lastCallAt: c.lastCallAt ?? existing.lastCallAt,
        firstCallAt: existing.firstCallAt ?? c.firstCallAt,
      );
      all[idx] = updated;
      await _save(all);
      return updated;
    }
    all.add(c);
    await _save(all);
    return c;
  }

  Future<void> update(Customer c) async {
    final all = await getAll();
    final i = all.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      all[i] = c;
      await _save(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await _save(all);
  }

  Future<Customer?> findByPhone(String phone) async {
    final norm = Customer.normalizePhone(phone);
    final all = await getAll();
    try {
      return all.firstWhere((e) => Customer.normalizePhone(e.phone) == norm);
    } catch (_) {
      return null;
    }
  }

  Future<Customer> recordCall(String phone, {String? name, int type = 2}) async {
    final existing = await findByPhone(phone);
    final now = DateTime.now();
    if (existing != null) {
      final updated = existing.copyWith(
        callCount: existing.callCount + 1,
        lastCallAt: now,
        firstCallAt: existing.firstCallAt ?? now,
        name: (name != null && name.isNotEmpty && !_isJunkName(name)) ? name : existing.name,
      );
      await update(updated);
      await addCallRecord(phone: phone, customerId: updated.id, type: type);
      return updated;
    }
    final resolved = await lookupNameFromDeviceContacts(phone);
    final finalName = (name != null && !_isJunkName(name))
        ? name
        : (resolved ?? phone);
    final c = Customer(
      name: finalName,
      phone: Customer.normalizePhone(phone),
      callCount: 1,
      firstCallAt: now,
      lastCallAt: now,
    );
    final saved = await add(c);
    await addCallRecord(phone: phone, customerId: saved.id, type: type);
    return saved;
  }

  /// نام‌های بی‌معنی اپراتور/سیستم را رد می‌کند
  static bool _isJunkName(String name) {
    final n = name.trim();
    if (n.isEmpty) return true;
    if (n.length < 2) return true;
    // مثل B.QMEHRIRAN یا فقط عدد
    if (RegExp(r'^[A-Z0-9.\-_+]+$').hasMatch(n) && !RegExp(r'[\u0600-\u06FF]').hasMatch(n)) {
      if (n.contains('.') || n.length > 12) return true;
    }
    if (RegExp(r'^\+?\d+$').hasMatch(n)) return true;
    return false;
  }

  Future<String?> lookupNameFromDeviceContacts(String phone) async {
    final name = await ContactCache.instance.lookup(phone);
    if (name != null && name.isNotEmpty && !_isJunkName(name)) return name;
    return null;
  }

  Future<List<Customer>> search(String q) async {
    final all = await getAll();
    if (q.trim().isEmpty) return all;
    final lower = q.trim().toLowerCase();
    return all.where((c) {
      return c.name.toLowerCase().contains(lower) ||
          c.phone.contains(lower) ||
          Customer.normalizePhone(c.phone).contains(Customer.normalizePhone(q));
    }).toList();
  }

  static const _callsKey = 'call_records_v1';

  Future<List<CallRecord>> getCallHistory({String? phone, String? customerId, int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_callsKey);
    if (raw == null || raw.isEmpty) return [];
    var list = (jsonDecode(raw) as List)
        .map((e) => CallRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (phone != null) {
      final n = Customer.normalizePhone(phone);
      list = list.where((c) => Customer.normalizePhone(c.phone) == n).toList();
    }
    if (customerId != null) {
      list = list.where((c) => c.customerId == customerId).toList();
    }
    list.sort((a, b) => b.at.compareTo(a.at));
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  Future<void> addCallRecord({
    required String phone,
    String? customerId,
    int type = 2,
    int durationSec = 0,
    DateTime? at,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_callsKey);
    final list = raw == null || raw.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    final rec = CallRecord(
      id: const Uuid().v4(),
      phone: Customer.normalizePhone(phone),
      customerId: customerId,
      type: type,
      at: at ?? DateTime.now(),
      durationSec: durationSec,
    );
    list.insert(0, rec.toJson());
    // cap storage for battery/storage
    while (list.length > 300) {
      list.removeLast();
    }
    await prefs.setString(_callsKey, jsonEncode(list));
  }

}
