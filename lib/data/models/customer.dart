import 'dart:convert';
import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  String name;
  String phone;
  String? note;
  int callCount;
  DateTime? firstCallAt;
  DateTime? lastCallAt;
  bool isFavorite;
  DateTime createdAt;

  Customer({
    String? id,
    required this.name,
    required this.phone,
    this.note,
    this.callCount = 0,
    this.firstCallAt,
    this.lastCallAt,
    this.isFavorite = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Customer copyWith({
    String? name,
    String? phone,
    String? note,
    int? callCount,
    DateTime? firstCallAt,
    DateTime? lastCallAt,
    bool? isFavorite,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      callCount: callCount ?? this.callCount,
      firstCallAt: firstCallAt ?? this.firstCallAt,
      lastCallAt: lastCallAt ?? this.lastCallAt,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'note': note,
      'callCount': callCount,
      'firstCallAt': firstCallAt?.toIso8601String(),
      'lastCallAt': lastCallAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      note: map['note'],
      callCount: map['callCount'] ?? 0,
      firstCallAt: map['firstCallAt'] != null ? DateTime.tryParse(map['firstCallAt']) : null,
      lastCallAt: map['lastCallAt'] != null ? DateTime.tryParse(map['lastCallAt']) : null,
      isFavorite: map['isFavorite'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) ?? DateTime.now() : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Customer.fromJson(String source) => Customer.fromMap(jsonDecode(source));
}
