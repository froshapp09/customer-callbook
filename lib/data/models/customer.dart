import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? note;
  final String tag; // مشتری، همکار، سایر
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
        'favorite': favorite,
        'callCount': callCount,
        'firstCallAt': firstCallAt?.toIso8601String(),
        'lastCallAt': lastCallAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String?,
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        note: j['note'] as String?,
        tag: (j['tag'] as String?) ?? 'مشتری',
        favorite: (j['favorite'] as bool?) ?? false,
        callCount: (j['callCount'] as int?) ?? 0,
        firstCallAt: j['firstCallAt'] != null ? DateTime.tryParse(j['firstCallAt']) : null,
        lastCallAt: j['lastCallAt'] != null ? DateTime.tryParse(j['lastCallAt']) : null,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      );

  static String normalizePhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (p.startsWith('+98')) p = '0${p.substring(3)}';
    if (p.startsWith('0098')) p = '0${p.substring(4)}';
    if (p.startsWith('98') && p.length >= 12) p = '0${p.substring(2)}';
    return p;
  }

  /// موبایل ایران: 09xxxxxxxxx (۱۱ رقم)
  static bool isMobile(String phone) {
    final n = normalizePhone(phone);
    return RegExp(r'^09\d{9}$').hasMatch(n);
  }

  /// شماره ثابت ایران (تقریبی)
  static bool isLandline(String phone) {
    final n = normalizePhone(phone);
    if (isMobile(n)) return false;
    // 0 + کد شهر (۲–۳ رقم) + شماره
    return RegExp(r'^0[1-8]\d{5,10}$').hasMatch(n);
  }

  static String phoneTypeLabel(String phone) {
    if (isMobile(phone)) return 'موبایل';
    if (isLandline(phone)) return 'ثابت';
    return 'سایر';
  }

  static String displayPhone(String phone) {
    final n = normalizePhone(phone);
    if (n.length == 11 && n.startsWith('09')) {
      return '${n.substring(0, 4)} ${n.substring(4, 7)} ${n.substring(7)}';
    }
    if (n.length >= 8 && n.startsWith('0')) {
      // ثابت: 021 1234 5678
      if (n.length == 11) {
        return '${n.substring(0, 3)} ${n.substring(3, 7)} ${n.substring(7)}';
      }
    }
    return phone;
  }

  /// برای واتساپ: 98912...
  static String toWhatsAppNumber(String phone) {
    var p = normalizePhone(phone);
    if (p.startsWith('0')) p = '98${p.substring(1)}';
    return p;
  }
}
