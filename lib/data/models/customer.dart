import 'package:uuid/uuid.dart';
import 'package:customer_callbook/core/utils/text_repair.dart';

/// وضعیت فروش تلفنی
class CustomerStatus {
  static const neu = 'جدید';
  static const negotiating = 'در حال مذاکره';
  static const purchased = 'خرید کرده';
  static const noAnswer = 'بی‌پاسخ';
  static const all = [neu, negotiating, purchased, noAnswer];

  static int colorValue(String s) {
    switch (s) {
      case negotiating:
        return 0xFFD97706;
      case purchased:
        return 0xFF16A34A;
      case noAnswer:
        return 0xFFDC2626;
      default:
        return 0xFF6C63FF;
    }
  }
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? note;
  final String tag; // مشتری، همکار، سایر
  final String status; // جدید، در حال مذاکره، ...
  final String? city;
  final double? orderAmount;
  final DateTime? reminderAt;
  final bool favorite;
  final int callCount;
  final DateTime? firstCallAt;
  final DateTime? lastCallAt;
  final DateTime createdAt;

  Customer({
    String? id,
    required this.name,
    required this.phone,
    this.note,
    this.tag = 'مشتری',
    this.status = CustomerStatus.neu,
    this.city,
    this.orderAmount,
    this.reminderAt,
    this.favorite = false,
    this.callCount = 0,
    this.firstCallAt,
    this.lastCallAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Customer copyWith({
    String? name,
    String? phone,
    String? note,
    String? tag,
    String? status,
    String? city,
    double? orderAmount,
    DateTime? reminderAt,
    bool clearReminder = false,
    bool? favorite,
    int? callCount,
    DateTime? firstCallAt,
    DateTime? lastCallAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      tag: tag ?? this.tag,
      status: status ?? this.status,
      city: city ?? this.city,
      orderAmount: orderAmount ?? this.orderAmount,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      favorite: favorite ?? this.favorite,
      callCount: callCount ?? this.callCount,
      firstCallAt: firstCallAt ?? this.firstCallAt,
      lastCallAt: lastCallAt ?? this.lastCallAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'tag': tag,
        'status': status,
        'city': city,
        'orderAmount': orderAmount,
        'reminderAt': reminderAt?.toIso8601String(),
        'favorite': favorite,
        'callCount': callCount,
        'firstCallAt': firstCallAt?.toIso8601String(),
        'lastCallAt': lastCallAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String?,
        name: TextRepair.fix((j['name'] as String?) ?? ''),
        phone: (j['phone'] as String?) ?? '',
        note: j['note'] != null ? TextRepair.fix(j['note'] as String) : null,
        tag: TextRepair.fix((j['tag'] as String?) ?? 'مشتری'),
        status: TextRepair.fix((j['status'] as String?) ?? CustomerStatus.neu),
        city: j['city'] != null ? TextRepair.fix(j['city'] as String) : null,
        orderAmount: (j['orderAmount'] as num?)?.toDouble(),
        reminderAt: j['reminderAt'] != null ? DateTime.tryParse(j['reminderAt']) : null,
        favorite: (j['favorite'] as bool?) ?? false,
        callCount: (j['callCount'] as int?) ?? 0,
        firstCallAt: j['firstCallAt'] != null ? DateTime.tryParse(j['firstCallAt']) : null,
        lastCallAt: j['lastCallAt'] != null ? DateTime.tryParse(j['lastCallAt']) : null,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      );

  static String normalizePhone(String phone) {
    // ارقام فارسی/عربی → انگلیسی
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var p = phone;
    for (var i = 0; i < 10; i++) {
      p = p.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    p = p.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('+98')) p = '0${p.substring(3)}';
    if (p.startsWith('0098')) p = '0${p.substring(4)}';
    if (p.startsWith('98') && p.length >= 12) p = '0${p.substring(2)}';
    // موبایل بدون صفر اول: 9xxxxxxxxx
    if (p.startsWith('9') && p.length == 10) p = '0$p';
    return p;
  }

  /// کلید تطبیق (۱۰ رقم آخر) — برای شناسایی یکسان با گوشی
  static String matchKey(String phone) {
    final p = normalizePhone(phone);
    if (p.length >= 10) return p.substring(p.length - 10);
    return p;
  }

  static bool samePhone(String a, String b) {
    final ka = matchKey(a);
    final kb = matchKey(b);
    if (ka.isEmpty || kb.isEmpty) return false;
    return ka == kb;
  }

  static String displayPhone(String phone) {
    final p = normalizePhone(phone);
    if (p.length == 11 && p.startsWith('09')) {
      return '${p.substring(0, 4)} ${p.substring(4, 7)} ${p.substring(7)}';
    }
    if (p.length >= 8) {
      // landline grouping rough
      if (p.startsWith('0') && p.length >= 10) {
        return '${p.substring(0, 3)} ${p.substring(3, 7)} ${p.substring(7)}';
      }
    }
    return p;
  }

  static bool isMobile(String phone) {
    final p = normalizePhone(phone);
    return p.startsWith('09') && p.length == 11;
  }

  static String phoneTypeLabel(String phone) => isMobile(phone) ? 'موبایل' : 'ثابت';

  /// شماره بین‌المللی بدون + برای wa.me
  static String toWhatsAppNumber(String phone) {
    var p = normalizePhone(phone);
    if (p.startsWith('0')) p = '98${p.substring(1)}';
    if (!p.startsWith('98')) p = '98$p';
    return p;
  }
}
